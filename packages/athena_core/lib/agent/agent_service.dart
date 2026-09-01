import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/schema_validator.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/model/token_usage.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

typedef PermissionCallback = Future<bool> Function(String toolName, String description);

/// beforeToolCall 上下文。
typedef BeforeToolCallContext = ({
  String name,
  String arguments,
  Map<String, dynamic> args,
});

/// beforeToolCall 返回结果。
typedef BeforeToolCallResult = ({bool block, String reason});

/// beforeToolCall 回调：返回 { block: true } 则拒绝执行。
typedef BeforeToolCallHook = Future<BeforeToolCallResult> Function(
  BeforeToolCallContext ctx,
);

/// afterToolCall 上下文。
typedef AfterToolCallContext = ({
  String name,
  String arguments,
  Map<String, dynamic> args,
  String rawResult,
  String processedResult,
});

/// afterToolCall 返回结果：可覆写 content / isError。
typedef AfterToolCallResult = ({String content, bool isError});

/// afterToolCall 回调：工具执行后处理结果。
typedef AfterToolCallHook = Future<AfterToolCallResult> Function(
  AfterToolCallContext ctx,
);

/// 单个 Agent run 的运行时状态（按 [runId] 隔离，支持多 run 并发）。
class _AgentRunState {
  _AgentRunState({CancelToken? token}) : cancelToken = token ?? CancelToken();

  final CancelToken cancelToken;
  final Completer<void> settled = Completer<void>();
  final List<ChatMessage> steerQueue = [];
  final List<ChatMessage> followUpQueue = [];
}

class AgentService {
  /// 并行工具执行的并发上限，防止模型一轮发大量并行调用时瞬时打爆。
  static const _maxParallelTools = 8;

  final ChatService _chatService;
  final ToolRegistry _toolRegistry;
  final SkillRegistry? _skillRegistry;

  // ─── 运行时状态（按 runId 隔离，多 run 可并发）────────────────
  final Map<int, _AgentRunState> _runs = {};

  /// 当前是否有 Agent 循环在运行（任一 run）。
  bool get isRunning => _runs.isNotEmpty;

  /// 指定 run 的取消令牌（可能为 null）。
  CancelToken? cancelTokenOf(int runId) => _runs[runId]?.cancelToken;

  /// 等待指定 run 完成后 resolve 的 Future。
  Future<void>? settledOf(int runId) => _runs[runId]?.settled.future;

  /// 注入一条 steering 消息：在当前轮工具执行完成后、下一轮 LLM 调用前插入。
  void steer(int runId, ChatMessage message) {
    _runs[runId]?.steerQueue.add(message);
  }

  /// 注入一条 followUp 消息：在 Agent 停止后作为新用户输入继续运行。
  void followUp(int runId, ChatMessage message) {
    _runs[runId]?.followUpQueue.add(message);
  }

  /// 清空指定 run 所有待注入的消息。
  void clearQueues(int runId) {
    final state = _runs[runId];
    state?.steerQueue.clear();
    state?.followUpQueue.clear();
  }

  AgentService({
    required ChatService chatService,
    required ToolRegistry toolRegistry,
    SkillRegistry? skillRegistry,
  })  : _chatService = chatService,
        _toolRegistry = toolRegistry,
        _skillRegistry = skillRegistry;

  /// 取消指定 run 的 Agent 循环。
  void abort(int runId) {
    _runs[runId]?.cancelToken.cancel();
  }

  Stream<AgentEvent> run({
    required int runId,
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? runtimePrompt,
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
    bool jsonMode = false,
  }) async* {
    if (_runs.containsKey(runId)) {
      throw StateError('Agent run $runId is already active.');
    }

    final state = _AgentRunState(token: cancelToken);
    _runs[runId] = state;
    final token = state.cancelToken;

    // 会话级权限缓存按 run 隔离：仅清空本 run 的
    permissionService?.resetSession(runId);

    var messages =
        _injectPrompts(baseMessages, skillPrompt, evolutionPrompt, runtimePrompt);
    _skillRegistry?.clearContext();

    // 构建复合 beforeToolCall：用户 hook → 权限检查
    final compositeBeforeToolCall = _buildCompositeBeforeHook(
      userHook: beforeToolCall,
      runId: runId,
      permissionService: permissionService,
      onPermission: onPermission,
      cancelToken: token,
    );

    // afterToolCall 无附加行为（权限判定在 before hook 内），直接透传
    final compositeAfterToolCall = afterToolCall;

    try {
      // 外层循环：followUp 消息可重启内层循环
      while (true) {
        var done = false;

        // 内层循环：工具调用迭代
        for (var iteration = 0;
            iteration < maxIterations && !done;
            iteration++) {
          token.throwIfCancelled();

          // 注入 steering 消息
          if (state.steerQueue.isNotEmpty) {
            final steerMessages = List<ChatMessage>.from(state.steerQueue);
            state.steerQueue.clear();
            messages.addAll(steerMessages);
          }

          yield AgentEvent.turnStart(iteration: iteration);

        final tools = _buildTools();
        final request = ChatCompletionCreateRequest(
          model: model.modelId,
          messages: messages,
          tools: tools,
          // jsonMode 场景（Shortcut 发起）：声明模型输出 JSON 对象
          responseFormat: jsonMode ? ResponseFormat.jsonObject() : null,
        );

        final stream = _chatService.getCompletion(
          chat: chat,
          messages: messages,
          provider: provider,
          model: model,
          tools: request.tools,
          responseFormat: request.responseFormat,
          cancelSignal: token.whenCancelled,
        );

        final accumulator = ChatStreamAccumulator();

        // 流式累积 tool_calls：id/name/arguments 分片到达，实时产出事件，
        // 避免等整个流结束后才一次性出现所有工具卡片。
        final streamingCalls = <int, _StreamingToolCall>{};
        final announcedIds = <String>{};

        try {
          await for (final chunk in stream) {
            token.throwIfCancelled();
            accumulator.add(chunk);

          final delta = chunk.firstChoice?.delta;
          if (delta != null) {
            final rc = delta.reasoningContent ?? delta.reasoning;
            if (rc != null && rc.isNotEmpty) {
              yield AgentEvent.reasoning(rc);
            }

            if (delta.toolCalls != null) {
              for (final tcd in delta.toolCalls!) {
                final acc = streamingCalls.putIfAbsent(
                  tcd.index,
                  _StreamingToolCall.new,
                );
                if (tcd.id != null) acc.id = tcd.id;
                final fnName = tcd.function?.name;
                if (fnName != null) acc.name ??= fnName;

                // 卡片出现时机：id 与 name 齐备（与 accumulator 建卡条件一致）。
                // 先于参数增量产出，保证同 chunk 内参数不丢失。
                if (acc.id != null &&
                    acc.name != null &&
                    !announcedIds.contains(acc.id)) {
                  announcedIds.add(acc.id!);
                  yield AgentEvent.toolCall(
                    id: acc.id!,
                    name: acc.name!,
                    arguments: acc.arguments,
                  );
                }

                final argsDelta = tcd.function?.arguments;
                if (argsDelta != null && argsDelta.isNotEmpty) {
                  acc.arguments += argsDelta;
                  // 仅已建卡（announced）时产出增量事件；未建卡的分片
                  // 已缓冲在 acc.arguments 中，由建卡事件一并携带。
                  if (acc.id != null && announcedIds.contains(acc.id)) {
                    yield AgentEvent.toolCallArgs(
                      id: acc.id!,
                      delta: argsDelta,
                    );
                  }
                }
              }
            }
          }

          final td = chunk.textDelta;
          if (td != null && td.isNotEmpty) {
            yield AgentEvent.text(td);
          }
          }
        } catch (e) {
          // 流异常（超时/网络/abort 触发）：若 token 已取消则统一以
          // CancelledException 呈现（取消优先于底层错误），否则原样抛出。
          token.throwIfCancelled();
          rethrow;
        }

        _logUsage(accumulator.usage);
        final usage = accumulator.usage;
        if (usage != null) {
          yield AgentEvent.usage(TokenUsage(
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens,
            totalTokens: usage.totalTokens,
            reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
            cachedTokens: usage.promptTokensDetails?.cachedTokens,
          ));
        }

        final toolCalls = accumulator.toolCalls;
        final truncated = accumulator.finishReason == FinishReason.length;

        if (toolCalls.isEmpty) {
          yield AgentEvent.done(content: accumulator.content);
          done = true;
          break;
        }

        // 追加 assistant 消息（含 tool_calls）
        // 注意：toolCall 事件已由流式循环实时产出，此处不再重复 yield
        final rc = model.reasoning && accumulator.reasoningContent.isNotEmpty
            ? accumulator.reasoningContent
            : null;
        messages.add(AssistantMessage(
          content: accumulator.content.isNotEmpty ? accumulator.content : null,
          toolCalls: toolCalls,
          reasoningContent: rc,
        ));

        // 截断保护：响应被 token 限制切断时，拒绝执行所有工具调用
        if (truncated) {
          final toolCallDataList = <Map<String, dynamic>>[];
          for (final tc in toolCalls) {
            const msg = 'Error: Tool call was not executed because the '
                'response hit the output token limit. Its arguments may be '
                'truncated. Re-issue the tool call with complete arguments.';
            yield AgentEvent.toolResult(
              id: tc.id,
              name: tc.function.name,
              result: msg,
            );
            messages.add(ChatMessage.tool(
              toolCallId: tc.id,
              content: msg,
            ));
            toolCallDataList.add({
              'id': tc.id,
              'name': tc.function.name,
              'arguments': tc.function.arguments,
              'result': msg,
            });
          }
          yield AgentEvent.iterationComplete(
            toolCalls: toolCallDataList,
            content: accumulator.content,
          );
          continue;
        }

        // 执行工具调用（串行 + 并行混合）
        final toolCallDataList = <Map<String, dynamic>>[];

        // 分组：可并行的调用经过权限预检后进入并行组，其余（含需弹窗
        // 审批的调用）进入串行组
        final parallelCalls = selectParallelCalls(
          toolCalls,
          runId: runId,
          permissionService: permissionService,
          onPermission: onPermission,
        );
        final sequentialCalls = [
          for (final tc in toolCalls)
            if (!parallelCalls.contains(tc)) tc,
        ];

        // 串行执行（弹窗审批天然逐个出现）
        for (final tc in sequentialCalls) {
          yield AgentEvent.toolExecutionStart(
            id: tc.id,
            name: tc.function.name,
            arguments: tc.function.arguments,
          );
          final data = await _executeOneTool(
            tc: tc,
            token: token,
            sentinelId: sentinelId,
            beforeHook: compositeBeforeToolCall,
            afterHook: compositeAfterToolCall,
          );
          yield data.event;
          messages.add(data.toolMessage);
          toolCallDataList.add(data.record);
        }

        // 并行执行：信号量限流 + 取消优先 + 结果渐进式产出
        if (parallelCalls.isNotEmpty) {
          for (final tc in parallelCalls) {
            yield AgentEvent.toolExecutionStart(
              id: tc.id,
              name: tc.function.name,
              arguments: tc.function.arguments,
            );
          }

          final semaphore = _AsyncSemaphore(_maxParallelTools);
          final futures = <Future<_ToolExecutionData>>{
            for (final tc in parallelCalls)
              _executeParallelOne(
                tc: tc,
                token: token,
                sentinelId: sentinelId,
                beforeHook: compositeBeforeToolCall,
                afterHook: compositeAfterToolCall,
                semaphore: semaphore,
              ),
          };

          while (futures.isNotEmpty) {
            // 每轮取最快完成的工具；取消信号优先返回，不等待卡住的工具
            final first = await Future.any([
              for (final f in futures) f.then((r) => (f: f, r: r)),
              token.whenCancelled.then((_) => null),
            ]);
            if (first == null) {
              // 取消：排空在飞的工具 Future（最多 2s），吞掉结果与错误，
              // 避免孤立 Future 继续执行副作用或产生未处理异常；
              // 已在执行的工具无法中断（工具级取消另行排期）。
              await Future.wait(
                futures.map((f) => f.then((_) {}, onError: (_) {})),
              ).timeout(const Duration(seconds: 2), onTimeout: () => []);
              token.throwIfCancelled();
            }
            futures.remove(first!.f);
            yield first.r.event;
            messages.add(first.r.toolMessage);
            toolCallDataList.add(first.r.record);
          }
        }

        yield AgentEvent.iterationComplete(
          toolCalls: toolCallDataList,
          content: accumulator.content,
        );
      }

        // 检查 followUp 消息：有则注入并重启内层循环
        if (state.followUpQueue.isNotEmpty) {
          final followUps = List<ChatMessage>.from(state.followUpQueue);
          state.followUpQueue.clear();
          messages.addAll(followUps);
        } else {
          break; // 无 followUp，退出外层循环
        }
      }
    } finally {
      _skillRegistry?.clearContext();
      _runs.remove(runId);
      if (!state.settled.isCompleted) state.settled.complete();
    }
  }

  /// 构建复合 beforeToolCall：用户 hook + 权限检查串联。
  BeforeToolCallHook? _buildCompositeBeforeHook({
    BeforeToolCallHook? userHook,
    required int runId,
    PermissionService? permissionService,
    PermissionCallback? onPermission,
    required CancelToken cancelToken,
  }) {
    if (userHook == null && permissionService == null && onPermission == null) {
      return null;
    }

    return (ctx) async {
      if (userHook != null) {
        final result = await userHook(ctx);
        if (result.block) return result;
      }

      if (permissionService == null && onPermission == null) {
        return (block: false, reason: '');
      }

      final verdict = permissionService?.check(
            runId,
            ctx.name,
            ctx.args,
            risk: _toolRegistry.get(ctx.name)?.risk,
          ) ??
          PermissionVerdict.prompt;

      if (verdict == PermissionVerdict.deny) {
        return (
          block: true,
          reason: 'Tool call denied by a permission rule.',
        );
      }

      if (verdict == PermissionVerdict.prompt) {
        if (onPermission == null) {
          return (
            block: true,
            reason: 'Error: Tool requires user approval but no permission '
                'callback is configured.',
          );
        }
        final approved = await Future.any<bool>([
          onPermission(ctx.name, ctx.arguments),
          cancelToken.whenCancelled.then((_) => false),
        ]);
        cancelToken.throwIfCancelled();
        if (!approved) {
          return (block: true, reason: 'User denied the tool execution.');
        }
      }

      return (block: false, reason: '');
    };
  }

  /// 首轮注入 skill / evolution / runtime prompt。
  ///
  /// runtimePrompt（运行环境事实）插入在所有 system 提示（sentinel、
  /// 记忆摘要、压缩摘要）之后、首个非 system 消息之前——即"系统提示词
  /// 后面"，与历史消息隔开，compact 时随 system 块完整保留。
  List<ChatMessage> _injectPrompts(
    List<ChatMessage> base,
    String? skillPrompt,
    String? evolutionPrompt,
    String? runtimePrompt,
  ) {
    var messages = List<ChatMessage>.from(base);
    if (skillPrompt != null && skillPrompt.isNotEmpty) {
      messages = [ChatMessage.system(skillPrompt), ...messages];
    }
    if (evolutionPrompt != null && evolutionPrompt.isNotEmpty) {
      messages = [ChatMessage.system(evolutionPrompt), ...messages];
    }
    if (runtimePrompt != null && runtimePrompt.isNotEmpty) {
      final index = messages.indexWhere((m) => m is! SystemMessage);
      final runtimeMessage = ChatMessage.system(runtimePrompt);
      if (index == -1) {
        messages.add(runtimeMessage);
      } else {
        messages.insert(index, runtimeMessage);
      }
    }
    return messages;
  }

  /// 从 ToolRegistry 构建 OpenAI Tool 列表。
  List<Tool>? _buildTools() {
    final defs = _toolRegistry.definitions;
    if (defs.isEmpty) return null;
    return defs
        .map((t) => Tool.function(
              name: t['function']['name'] as String,
              description: t['function']['description'] as String,
              parameters: t['function']['parameters'] as Map<String, dynamic>,
            ))
        .toList();
  }

  /// 执行单个工具调用：校验 → beforeToolCall → 权限检查 → 执行 → afterToolCall。
  Future<ToolCallResultInternal> executeToolCallInternal({
    required ToolCall toolCall,
    required CancelToken? cancelToken,
    String? sentinelId,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
  }) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
    } catch (_) {
      final msg = 'Error: Failed to parse tool call arguments as JSON: '
          '${toolCall.function.arguments}';
      return ToolCallResultInternal(
        event: AgentToolResultEvent(
          id: toolCall.id,
          name: toolCall.function.name,
          result: msg,
        ),
        processedResult: msg,
        rawResult: msg,
      );
    }

    final tool = _toolRegistry.get(toolCall.function.name);

    // 参数校验
    if (tool != null) {
      final validationError = SchemaValidator.validate(tool.parameters, args);
      if (validationError != null) {
        final msg = 'Error: Invalid arguments for tool '
            '"${toolCall.function.name}": $validationError';
        return ToolCallResultInternal(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
          ),
          processedResult: msg,
          rawResult: msg,
        );
      }
    }

    // beforeToolCall hook
    if (beforeToolCall != null) {
      final beforeResult = await beforeToolCall((
        name: toolCall.function.name,
        arguments: toolCall.function.arguments,
        args: args,
      ));
      if (beforeResult.block) {
        final msg = beforeResult.reason.isEmpty
            ? 'Tool execution was blocked by beforeToolCall hook.'
            : beforeResult.reason;
        return ToolCallResultInternal(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
          ),
          processedResult: msg,
          rawResult: msg,
        );
      }
    }

    cancelToken?.throwIfCancelled();
    if (sentinelId != null) {
      args['_sentinel_id'] = sentinelId;
    }

    final rawResult = tool != null
        ? await tool.execute(args)
        : 'Error: Unknown tool "${toolCall.function.name}"';

    var processed = smartTruncate(rawResult);

    // afterToolCall hook（摘要等可选后处理，由调用方注入；
    // AgentRunCoordinator 当前未注入，实际生效的截断是上面的 smartTruncate）
    if (afterToolCall != null) {
      final afterResult = await afterToolCall((
        name: toolCall.function.name,
        arguments: toolCall.function.arguments,
        args: args,
        rawResult: rawResult,
        processedResult: processed,
      ));
      processed = afterResult.content;
    }

    return ToolCallResultInternal(
      event: AgentToolResultEvent(
        id: toolCall.id,
        name: toolCall.function.name,
        result: rawResult,
      ),
      processedResult: processed,
      rawResult: rawResult,
    );
  }

  void _logUsage(Usage? usage) {
    // 纯 Dart 等价于 kDebugMode（flutter/foundation 的 kDebugMode = !kReleaseMode）
    if (const bool.fromEnvironment('dart.vm.product')) return;
    if (usage != null) {
      LoggerUtil.d(
        'agent usage: prompt=${usage.promptTokens} '
        'completion=${usage.completionTokens} '
        'total=${usage.totalTokens} '
        'cached=${usage.promptTokensDetails?.cachedTokens}',
      );
    } else {
      LoggerUtil.w(
        'agent usage: provider 返回的流中未携带 usage（多数是该 '
        'provider/model 不支持 stream_options.include_usage）',
      );
    }
  }

  /// 从 [toolCalls] 中选出可并行执行的一批，经过权限预检分级。
  ///
  /// 预检目的：并行组内不得出现需要审批弹窗的调用（多个模态 dialog
  /// 同时弹出会互相覆盖），因此：
  /// - [permissionService] 非空时，`check` 返回 [PermissionVerdict.allow]
  ///   （readOnly / 会话缓存 / 持久规则命中）才留在并行组，
  ///   需弹窗或拒绝（[PermissionVerdict.prompt] / [deny]）的降级串行;
  /// - [permissionService] 为空但 [onPermission] 非空（无预检能力）时，
  ///   候选并行调用全部降级串行（保守）；
  /// - 两者皆空（无权限系统）时不做降级。
  ///
  /// 参数解析失败、工具不存在或工具判定不可并行的调用归入串行组。
  @visibleForTesting
  List<ToolCall> selectParallelCalls(
    List<ToolCall> toolCalls, {
    required int runId,
    PermissionService? permissionService,
    PermissionCallback? onPermission,
  }) {
    final parallelCalls = <ToolCall>[];
    for (final tc in toolCalls) {
      final tool = _toolRegistry.get(tc.function.name);
      Map<String, dynamic>? args;
      try {
        args = jsonDecode(tc.function.arguments) as Map<String, dynamic>;
      } catch (_) {
        args = null;
      }

      if (args == null || tool == null || !tool.canExecuteParallel(args)) {
        continue;
      }

      // 权限预检分级：需弹窗的调用降级串行
      if (permissionService != null) {
        if (permissionService.check(
              runId,
              tc.function.name,
              args,
              risk: tool.risk,
            ) !=
            PermissionVerdict.allow) {
          continue;
        }
      } else if (onPermission != null) {
        continue;
      }

      parallelCalls.add(tc);
    }
    return parallelCalls;
  }

  /// 并行执行单个工具，受 [semaphore] 限流。
  Future<_ToolExecutionData> _executeParallelOne({
    required ToolCall tc,
    required CancelToken token,
    String? sentinelId,
    BeforeToolCallHook? beforeHook,
    AfterToolCallHook? afterHook,
    required _AsyncSemaphore semaphore,
  }) async {
    await semaphore.acquire();
    try {
      return await _executeOneTool(
        tc: tc,
        token: token,
        sentinelId: sentinelId,
        beforeHook: beforeHook,
        afterHook: afterHook,
      );
    } finally {
      semaphore.release();
    }
  }

  /// 执行单个工具并返回打包数据（供串行/并行执行复用）。
  Future<_ToolExecutionData> _executeOneTool({
    required ToolCall tc,
    required CancelToken token,
    String? sentinelId,
    BeforeToolCallHook? beforeHook,
    AfterToolCallHook? afterHook,
  }) async {
    final result = await executeToolCallInternal(
      toolCall: tc,
      cancelToken: token,
      sentinelId: sentinelId,
      beforeToolCall: beforeHook,
      afterToolCall: afterHook,
    );
    return _ToolExecutionData(
      event: AgentToolResultEvent(
        id: tc.id,
        name: tc.function.name,
        result: result.rawResult,
      ),
      toolMessage: ChatMessage.tool(
        toolCallId: tc.id,
        content: result.processedResult,
      ),
      record: {
        'id': tc.id,
        'name': tc.function.name,
        'arguments': tc.function.arguments,
        'result': result.rawResult,
      },
    );
  }

  String smartTruncate(String result, {int threshold = 12000}) {
    if (result.length <= threshold) return result;
    final headLen = (threshold * 0.6).round();
    final tailLen = threshold - headLen;
    final head = result.substring(0, headLen);
    final tail = result.substring(result.length - tailLen);
    final skipped = result.length - headLen - tailLen;
    return '$head\n\n... [truncated $skipped characters] ...\n\n$tail';
  }


}

/// 简单的异步信号量，限制并发执行数（FIFO 公平）。
class _AsyncSemaphore {
  final int _max;
  int _current = 0;
  final List<Completer<void>> _waiters = [];

  _AsyncSemaphore(this._max);

  Future<void> acquire() async {
    if (_current < _max) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void release() {
    // 有等待者时直接把 permit 让给队首，否则归还计数
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _current--;
    }
  }
}

/// 流式累积中的单个 tool_call：id/name/arguments 分片到达。
class _StreamingToolCall {
  String? id;
  String? name;
  String arguments = '';
}

/// 单个工具执行的结果打包。供 [_executeOneTool] 返回。
class _ToolExecutionData {
  final AgentToolResultEvent event;
  final ChatMessage toolMessage;
  final Map<String, dynamic> record;
  const _ToolExecutionData({
    required this.event,
    required this.toolMessage,
    required this.record,
  });
}

/// 单个工具调用的执行结果。
@visibleForTesting
class ToolCallResultInternal {
  final AgentToolResultEvent event;
  final String processedResult;
  final String rawResult;
  const ToolCallResultInternal({
    required this.event,
    required this.processedResult,
    required this.rawResult,
  });
}

sealed class AgentEvent {
  const AgentEvent();

  const factory AgentEvent.text(String delta) = AgentTextEvent;

  const factory AgentEvent.reasoning(String delta) = AgentReasoningEvent;

  const factory AgentEvent.toolCall({
    required String id,
    required String name,
    required String arguments,
  }) = AgentToolCallEvent;

  /// 流式 tool_call 参数增量：卡片已出现后，参数分片实时追加。
  const factory AgentEvent.toolCallArgs({
    required String id,
    required String delta,
  }) = AgentToolCallArgsEvent;

  const factory AgentEvent.toolResult({
    required String id,
    required String name,
    required String result,
  }) = AgentToolResultEvent;

  const factory AgentEvent.iterationComplete({
    required List<Map<String, dynamic>> toolCalls,
    required String content,
  }) = AgentIterationCompleteEvent;

  const factory AgentEvent.done({required String content}) = AgentDoneEvent;

  const factory AgentEvent.turnStart({required int iteration}) = AgentTurnStartEvent;

  const factory AgentEvent.toolExecutionStart({
    required String id,
    required String name,
    required String arguments,
  }) = AgentToolExecutionStartEvent;

  const factory AgentEvent.toolExecutionUpdate({
    required String id,
    required String name,
    required String partialResult,
  }) = AgentToolExecutionUpdateEvent;

  const factory AgentEvent.usage(TokenUsage usage) = AgentUsageEvent;
}

class AgentTextEvent extends AgentEvent {
  final String delta;
  const AgentTextEvent(this.delta);
}

class AgentReasoningEvent extends AgentEvent {
  final String delta;
  const AgentReasoningEvent(this.delta);
}

class AgentToolCallEvent extends AgentEvent {
  final String id;
  final String name;
  final String arguments;
  const AgentToolCallEvent({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

/// 流式 tool_call 参数增量事件。
class AgentToolCallArgsEvent extends AgentEvent {
  final String id;

  /// 本次 chunk 携带的 arguments 分片（非完整参数）。
  final String delta;
  const AgentToolCallArgsEvent({
    required this.id,
    required this.delta,
  });
}

class AgentToolResultEvent extends AgentEvent {
  final String id;
  final String name;
  final String result;
  const AgentToolResultEvent({
    required this.id,
    required this.name,
    required this.result,
  });
}

class AgentIterationCompleteEvent extends AgentEvent {
  final List<Map<String, dynamic>> toolCalls;
  final String content;
  const AgentIterationCompleteEvent({
    required this.toolCalls,
    required this.content,
  });
}

class AgentDoneEvent extends AgentEvent {
  final String content;
  const AgentDoneEvent({required this.content});
}

class AgentUsageEvent extends AgentEvent {
  final TokenUsage usage;
  const AgentUsageEvent(this.usage);
}

class AgentTurnStartEvent extends AgentEvent {
  final int iteration;
  const AgentTurnStartEvent({required this.iteration});
}

class AgentToolExecutionStartEvent extends AgentEvent {
  final String id;
  final String name;
  final String arguments;
  const AgentToolExecutionStartEvent({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class AgentToolExecutionUpdateEvent extends AgentEvent {
  final String id;
  final String name;
  final String partialResult;
  const AgentToolExecutionUpdateEvent({
    required this.id,
    required this.name,
    required this.partialResult,
  });
}

