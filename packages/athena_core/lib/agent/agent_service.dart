import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/evolution/reflection.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/schema_validator.dart';
import 'package:athena_core/agent/tool/tool_interface.dart'
    show CancellableTool;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

typedef PermissionCallback =
    Future<bool> Function(String toolName, String description);

/// beforeToolCall 上下文。
typedef BeforeToolCallContext = ({
  String name,
  String arguments,
  Map<String, dynamic> args,
});

/// beforeToolCall 返回结果。
typedef BeforeToolCallResult = ({bool block, String reason});

/// 工具执行前的权限门：返回 { block: true } 则拒绝执行。
typedef PermissionGate =
    Future<BeforeToolCallResult> Function(BeforeToolCallContext ctx);

/// 单个 Agent run 的运行时状态（按 [runId] 隔离，支持多 run 并发）。
class _AgentRunState {
  _AgentRunState({CancelToken? token}) : cancelToken = token ?? CancelToken();

  final CancelToken cancelToken;
  final Completer<void> settled = Completer<void>();
}

class AgentService {
  /// 并行工具执行的并发上限，防止模型一轮发大量并行调用时瞬时打爆。
  static const _maxParallelTools = 8;

  final ChatCompletionsService _chatService;
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


  AgentService({
    required ChatCompletionsService chatService,
    required ToolRegistry toolRegistry,
    SkillRegistry? skillRegistry,
  }) : _chatService = chatService,
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
    bool hasSentinelPrompt = true,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
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

    var messages = _injectPrompts(
      baseMessages,
      skillPrompt,
      evolutionPrompt,
      runtimePrompt,
      hasSentinelPrompt: hasSentinelPrompt,
    );
    _skillRegistry?.clearContext();

    // 权限门：权限检查 + 审批回调，工具执行前逐调用拦截
    final permissionGate = _buildPermissionGate(
      runId: runId,
      permissionService: permissionService,
      onPermission: onPermission,
      cancelToken: token,
    );

    try {
      yield* _AgentLoop(
        service: this,
        state: state,
        chat: chat,
        provider: provider,
        model: model,
        messages: messages,
        runId: runId,
        sentinelId: sentinelId,
        maxIterations: maxIterations,
        jsonMode: jsonMode,
        permissionGate: permissionGate,
        permissionService: permissionService,
        onPermission: onPermission,
      ).run();
    } on CancelledException {
      rethrow;
    } finally {
      _skillRegistry?.clearContext();
      _runs.remove(runId);
      if (!state.settled.isCompleted) state.settled.complete();
    }
  }

  /// 执行单个工具调用：参数校验 → 权限门 → 执行。
  ///
  /// 供测试直接驱动工具执行路径（跳过 run 事件流）使用。
  @visibleForTesting
  Future<ToolCallResultInternal> executeToolCallInternal({
    required ToolCall toolCall,
    required CancelToken? cancelToken,
    String? sentinelId,
    PermissionGate? permissionGate,
  }) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
    } catch (_) {
      final msg =
          'Error: Failed to parse tool call arguments as JSON: '
          '${toolCall.function.arguments}';
      return ToolCallResultInternal(
        event: AgentToolResultEvent(
          id: toolCall.id,
          name: toolCall.function.name,
          result: msg,
          status: ToolResultStatus.invalidArguments,
        ),
        processedResult: msg,
        rawResult: msg,
        status: ToolResultStatus.invalidArguments,
      );
    }

    final tool = _toolRegistry.get(toolCall.function.name);

    // 参数校验
    if (tool != null) {
      final validationError = SchemaValidator.validate(tool.parameters, args);
      if (validationError != null) {
        final msg =
            'Error: Invalid arguments for tool '
            '"${toolCall.function.name}": $validationError';
        return ToolCallResultInternal(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
            status: ToolResultStatus.invalidArguments,
          ),
          processedResult: msg,
          rawResult: msg,
          status: ToolResultStatus.invalidArguments,
        );
      }
    }

    // 权限门（拦截或放行）
    if (permissionGate != null) {
      final gateResult = await permissionGate((
        name: toolCall.function.name,
        arguments: toolCall.function.arguments,
        args: args,
      ));
      if (gateResult.block) {
        final msg = gateResult.reason.isEmpty
            ? 'Tool execution was blocked by the permission gate.'
            : gateResult.reason;
        return ToolCallResultInternal(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
            status: ToolResultStatus.blocked,
          ),
          processedResult: msg,
          rawResult: msg,
          status: ToolResultStatus.blocked,
        );
      }
    }

    cancelToken?.throwIfCancelled();
    if (sentinelId != null) {
      args['_sentinel_id'] = sentinelId;
    }

    final String rawResult;
    var status = ToolResultStatus.success;
    if (tool == null) {
      rawResult = 'Error: Unknown tool "${toolCall.function.name}"';
      status = ToolResultStatus.executionError;
    } else if (cancelToken != null && tool is CancellableTool) {
      rawResult = await (tool as CancellableTool).executeCancellable(
        args,
        cancelSignal: cancelToken.whenCancelled,
      );
    } else {
      rawResult = await tool.execute(args);
    }
    cancelToken?.throwIfCancelled();

    if (rawResult.trimLeft().startsWith('Error')) {
      status = ToolResultStatus.executionError;
    }

    var processed = smartTruncate(rawResult);

    return ToolCallResultInternal(
      event: AgentToolResultEvent(
        id: toolCall.id,
        name: toolCall.function.name,
        result: rawResult,
        status: status,
      ),
      processedResult: processed,
      rawResult: rawResult,
      status: status,
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

  /// 构建工具执行前的权限门：权限检查 + 审批回调。
  PermissionGate? _buildPermissionGate({
    required int runId,
    PermissionService? permissionService,
    PermissionCallback? onPermission,
    required CancelToken cancelToken,
  }) {
    if (permissionService == null && onPermission == null) {
      return null;
    }

    return (ctx) async {
      final verdict =
          permissionService?.check(
            runId,
            ctx.name,
            ctx.args,
            risk: _toolRegistry.get(ctx.name)?.risk,
          ) ??
          PermissionVerdict.prompt;

      if (verdict == PermissionVerdict.deny) {
        return (block: true, reason: 'Tool call denied by a permission rule.');
      }

      if (verdict == PermissionVerdict.prompt) {
        if (onPermission == null) {
          return (
            block: true,
            reason:
                'Error: Tool requires user approval but no permission '
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

  /// 首轮注入 runtime / evolution / skill prompt。
  ///
  /// 目标布局（按语义分层，缓存前缀稳定）：
  ///   [sentinel, runtime, evolution, system-summaries?, history...]
  ///
  /// base 约定（ChatMessageConverter.buildMessages）：[hasSentinelPrompt] 为
  /// true 时首个 system 是 sentinel，其后的 system 是上下文摘要（稳定的
  /// active memory catalog 或历史 compact 摘要）；为 false 时所有 system
  /// 都是上下文摘要。非 system 是对话历史。
  /// - 静态注入段（runtime / evolution / skill，内容恒定）插在 sentinel
  ///   之后、历史类摘要之前——指令层连续，摘要保持"历史区头部"。
  List<ChatMessage> _injectPrompts(
    List<ChatMessage> base,
    String? skillPrompt,
    String? evolutionPrompt,
    String? runtimePrompt, {
    required bool hasSentinelPrompt,
  }) {
    var sentinelEnd = -1;
    if (hasSentinelPrompt) {
      for (var i = 0; i < base.length; i++) {
        if (base[i] is SystemMessage) {
          sentinelEnd = i;
          break;
        }
      }
    }

    final staticBlocks = <ChatMessage>[
      if (runtimePrompt != null && runtimePrompt.isNotEmpty)
        ChatMessage.system(runtimePrompt),
      if (evolutionPrompt != null && evolutionPrompt.isNotEmpty)
        ChatMessage.system(evolutionPrompt),
      if (skillPrompt != null && skillPrompt.isNotEmpty)
        ChatMessage.system(skillPrompt),
    ];

    final head = <ChatMessage>[];
    final summaries = <ChatMessage>[];
    final history = <ChatMessage>[];
    for (var i = 0; i < base.length; i++) {
      final m = base[i];
      if (i == sentinelEnd) {
        head.add(m); // sentinel
      } else if (m is SystemMessage) {
        summaries.add(m); // 历史类摘要（memory digest / compact）
      } else {
        history.add(m);
      }
    }
    return [...head, ...staticBlocks, ...summaries, ...history];
  }

  /// 从 ToolRegistry 构建 OpenAI Tool 列表。
  List<Tool>? _buildTools() {
    final defs = _toolRegistry.definitions;
    if (defs.isEmpty) return null;
    return defs
        .map(
          (t) => Tool.function(
            name: t['function']['name'] as String,
            description: t['function']['description'] as String,
            parameters: t['function']['parameters'] as Map<String, dynamic>,
          ),
        )
        .toList();
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

/// 单次 Agent run 的驱动循环（外层 followUp 循环 + 内层工具迭代）。
///
/// 从 [AgentService.run] 中独立出来，把一次 run 的完整生命周期
/// （流式消费、截断保护、串行/并行执行、反思、outcome 汇总）收拢到
/// 职责单一的私有类；[AgentService.run] 仅负责 run 状态注册与清理。
class _AgentLoop {
  _AgentLoop({
    required AgentService service,
    required _AgentRunState state,
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> messages,
    required int runId,
    required String? sentinelId,
    required int maxIterations,
    required bool jsonMode,
    required PermissionGate? permissionGate,
    required PermissionService? permissionService,
    required PermissionCallback? onPermission,
  }) : _service = service,
       _state = state,
       _chat = chat,
       _provider = provider,
       _model = model,
       _messages = messages,
       _runId = runId,
       _sentinelId = sentinelId,
       _maxIterations = maxIterations,
       _jsonMode = jsonMode,
       _permissionGate = permissionGate,
       _permissionService = permissionService,
       _onPermission = onPermission;

  final AgentService _service;
  final _AgentRunState _state;
  final ChatEntity _chat;
  final ProviderEntity _provider;
  final ModelEntity _model;

  /// 正在演进的上下文（本轮工具结果 / steering / followUp 持续追加）。
  final List<ChatMessage> _messages;
  final int _runId;
  final String? _sentinelId;
  final int _maxIterations;
  final bool _jsonMode;
  final PermissionGate? _permissionGate;
  final PermissionService? _permissionService;
  final PermissionCallback? _onPermission;

  CancelToken get _token => _state.cancelToken;

  int _iterationsExecuted = 0;
  final List<ToolFailure> _toolFailures = [];
  var _termination = AgentRunTermination.completed;
  var _reflectionAttempted = false;

  /// 执行整个 run：单层工具迭代循环，结束后触发反思并产出 outcome。
  ///
  /// 运行中输入不在此层处理：协调层（AgentRunCoordinator）把运行中收到
  /// 的用户消息落库排队，本 run 结束后作为新 run 自动接续。
  Stream<AgentEvent> run() async* {
    try {
      var done = false;
      for (
        var iteration = 0;
        iteration < _maxIterations && !done;
        iteration++
      ) {
        final st = _TurnState();
        yield* _runIteration(iteration, st);
        done = st.done;
      }
      _termination = done
          ? AgentRunTermination.completed
          : AgentRunTermination.maxIterations;

      yield* _maybeReflect();
    } on CancelledException catch (e) {
      yield AgentEvent.outcome(
        AgentRunOutcome(
          termination: AgentRunTermination.cancelled,
          iterations: _iterationsExecuted,
          toolFailures: List.unmodifiable(_toolFailures),
          reflectionAttempted: _reflectionAttempted,
          error: e.toString(),
        ),
      );
      rethrow;
    } catch (e) {
      yield AgentEvent.outcome(
        AgentRunOutcome(
          termination: AgentRunTermination.error,
          iterations: _iterationsExecuted,
          toolFailures: List.unmodifiable(_toolFailures),
          reflectionAttempted: _reflectionAttempted,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// 单轮迭代：取消检查 → LLM 流式 → 追加 assistant 消息
  /// → 截断保护 → 工具执行 → iterationComplete。
  ///
  /// 完成状态写入 [st]（done = 模型主动结束、无工具调用）。
  Stream<AgentEvent> _runIteration(int iteration, _TurnState st) async* {
    _token.throwIfCancelled();

    yield AgentEvent.turnStart(iteration: iteration);
    _iterationsExecuted++;

    final tools = _service._buildTools();
    final request = ChatCompletionCreateRequest(
      model: _model.modelId,
      messages: _messages,
      tools: tools,
      // jsonMode 场景（Shortcut 发起）：声明模型输出 JSON 对象
      responseFormat: _jsonMode ? ResponseFormat.jsonObject() : null,
    );

    yield* _streamTurn(request, st);

    final toolCalls = st.accumulator.toolCalls;
    final truncated = st.accumulator.finishReason == FinishReason.length;

    if (toolCalls.isEmpty) {
      yield AgentEvent.done(content: st.accumulator.content);
      st.done = true;
      return;
    }

    // 追加 assistant 消息（含 tool_calls）
    // 注意：toolCall 事件已由流式循环实时产出，此处不再重复 yield
    final rc = _model.reasoning && st.accumulator.reasoningContent.isNotEmpty
        ? st.accumulator.reasoningContent
        : null;
    _messages.add(
      AssistantMessage(
        content: st.accumulator.content.isNotEmpty
            ? st.accumulator.content
            : null,
        toolCalls: toolCalls,
        reasoningContent: rc,
      ),
    );

    // 截断保护：响应被 token 限制切断时，拒绝执行所有工具调用
    if (truncated) {
      yield* _handleTruncated(toolCalls, st.accumulator.content);
      return;
    }

    // 执行工具调用（串行 + 并行混合）
    yield* _executeToolCalls(toolCalls, st.accumulator.content);
  }

  /// 仅 LLM 流式消费：reasoning / tool_calls 分片 / text 实时产出事件，
  /// 流异常归一化（取消优先于底层错误），累积结果写入 [st.accumulator]。
  Stream<AgentEvent> _streamTurn(
    ChatCompletionCreateRequest request,
    _TurnState st,
  ) async* {
    final stream = _service._chatService.getCompletion(
      chat: _chat,
      messages: request.messages,
      provider: _provider,
      model: _model,
      tools: request.tools,
      responseFormat: request.responseFormat,
      cancelSignal: _token.whenCancelled,
    );

    // 流式累积 tool_calls: id/name/arguments 分片到达，实时产出事件，
    // 避免等整个流结束后才一次性出现所有工具卡片。
    // streamingCalls / announcedIds 仅本轮流式期间使用，故作为局部状态。
    final streamingCalls = <int, _StreamingToolCall>{};
    final announcedIds = <String>{};

    try {
      await for (final chunk in stream) {
        _token.throwIfCancelled();
        st.accumulator.add(chunk);

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
      _token.throwIfCancelled();
      rethrow;
    }

    _service._logUsage(st.accumulator.usage);
    final usage = st.accumulator.usage;
    if (usage != null) {
      yield AgentEvent.usage(
        TokenUsage(
          promptTokens: usage.promptTokens,
          completionTokens: usage.completionTokens,
          totalTokens: usage.totalTokens,
          reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
          cachedTokens: usage.promptTokensDetails?.cachedTokens,
        ),
      );
    }
  }

  /// 截断保护：响应被 token 限制切断时，拒绝执行所有工具调用。
  ///
  /// 产出逐条的 modelTruncated 错误结果与 iterationComplete，
  /// 供模型在下一轮以完整参数重新发起。
  Stream<AgentEvent> _handleTruncated(
    List<ToolCall> toolCalls,
    String content,
  ) async* {
    final toolCallDataList = <Map<String, dynamic>>[];
    for (final tc in toolCalls) {
      const msg =
          'Error: Tool call was not executed because the '
          'response hit the output token limit. Its arguments may be '
          'truncated. Re-issue the tool call with complete arguments.';
      yield AgentEvent.toolResult(
        id: tc.id,
        name: tc.function.name,
        result: msg,
        status: ToolResultStatus.modelTruncated,
      );
      _toolFailures.add(
        ToolFailure(
          toolName: tc.function.name,
          status: ToolResultStatus.modelTruncated,
          message: msg,
        ),
      );
      _messages.add(ChatMessage.tool(toolCallId: tc.id, content: msg));
      toolCallDataList.add({
        'id': tc.id,
        'name': tc.function.name,
        'arguments': tc.function.arguments,
        'result': msg,
      });
    }
    yield AgentEvent.iterationComplete(
      toolCalls: toolCallDataList,
      content: content,
    );
  }

  /// 执行一轮的工具调用：分组（可并行 / 串行）→ 串行段 → 并行段 →
  /// iterationComplete。
  Stream<AgentEvent> _executeToolCalls(
    List<ToolCall> toolCalls,
    String content,
  ) async* {
    final toolCallDataList = <Map<String, dynamic>>[];

    // 分组：可并行的调用经过权限预检后进入并行组，其余（含需弹窗
    // 审批的调用）进入串行组
    final parallelCalls = _service.selectParallelCalls(
      toolCalls,
      runId: _runId,
      permissionService: _permissionService,
      onPermission: _onPermission,
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
      final data = await _executeOneTool(tc: tc);
      yield data.event;
      _messages.add(data.toolMessage);
      toolCallDataList.add(data.record);
      _recordFailure(data.event);
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

      final semaphore = _AsyncSemaphore(AgentService._maxParallelTools);
      final futures = <Future<_ToolExecutionData>>{
        for (final tc in parallelCalls) _executeParallelOne(tc: tc, semaphore: semaphore),
      };

      while (futures.isNotEmpty) {
        // 每轮取最快完成的工具；取消信号优先返回，不等待卡住的工具
        final first = await Future.any([
          for (final f in futures) f.then((r) => (f: f, r: r)),
          _token.whenCancelled.then((_) => null),
        ]);
        if (first == null) {
          // 取消：排空在飞的工具 Future（最多 2s），吞掉结果与错误，
          // 避免孤立 Future 继续执行副作用或产生未处理异常；
          // 已在执行的工具无法中断（工具级取消另行排期）。
          await Future.wait(
            futures.map((f) => f.then((_) {}, onError: (_) {})),
          ).timeout(const Duration(seconds: 2), onTimeout: () => []);
          _token.throwIfCancelled();
        }
        futures.remove(first!.f);
        yield first.r.event;
        _messages.add(first.r.toolMessage);
        toolCallDataList.add(first.r.record);
        _recordFailure(first.r.event);
      }
    }

    yield AgentEvent.iterationComplete(
      toolCalls: toolCallDataList,
      content: content,
    );
  }

  /// 反思通道：失败可归因时让模型提炼长期经验，
  /// 经 experience_learn 标准工具路径（校验/审批/执行）写入。
  Stream<AgentEvent> _maybeReflect() async* {
    var outcome = AgentRunOutcome(
      termination: _termination,
      iterations: _iterationsExecuted,
      toolFailures: List.unmodifiable(_toolFailures),
    );
    if (ReflectionPolicy.shouldReflect(outcome) &&
        _service._toolRegistry.get('experience_learn') != null) {
      _reflectionAttempted = true;
      try {
        yield* _runReflection(
          outcome: outcome,
          task: _latestUserTask(),
          iteration: _iterationsExecuted,
        );
      } on CancelledException {
        rethrow;
      } catch (e) {
        // Reflection 是附加学习路径；失败不能把原任务改写成运行错误。
        LoggerUtil.w('Reflection skipped after failure: $e');
      }
    }
    outcome = AgentRunOutcome(
      termination: _termination,
      iterations: _iterationsExecuted,
      toolFailures: List.unmodifiable(_toolFailures),
      reflectionAttempted: _reflectionAttempted,
    );
    yield AgentEvent.outcome(outcome);
  }

  /// 失败反思：仅做一次 LLM 提案调用，经验写入完全复用普通工具路径。
  Stream<AgentEvent> _runReflection({
    required AgentRunOutcome outcome,
    required String task,
    required int iteration,
  }) async* {
    _token.throwIfCancelled();
    final response = await _service._chatService.complete(
      messages: [
        ChatMessage.system(ReflectionPrompt.system),
        ChatMessage.user(ReflectionPrompt.input(outcome: outcome, task: task)),
      ],
      provider: _provider,
      model: _model,
      cancelSignal: _token.whenCancelled,
    );
    _token.throwIfCancelled();

    final proposal = ReflectionProposal.tryParse(response);
    if (proposal == null) return;

    final arguments = jsonEncode(proposal.toToolArguments());
    final id = 'reflection_$iteration';
    final toolCall = ToolCall(
      id: id,
      type: 'function',
      function: FunctionCall(name: 'experience_learn', arguments: arguments),
    );

    // Reflection 只生成标准工具调用；参数校验、权限审批与执行完全复用
    // 普通 Agent 工具路径，不直接写 ExperienceRepository。
    yield AgentEvent.turnStart(iteration: iteration);
    yield AgentEvent.toolCall(
      id: id,
      name: 'experience_learn',
      arguments: arguments,
    );
    yield AgentEvent.toolExecutionStart(
      id: id,
      name: 'experience_learn',
      arguments: arguments,
    );
    final data = await _executeOneTool(tc: toolCall);
    yield data.event;
    yield AgentEvent.iterationComplete(toolCalls: [data.record], content: '');
  }

  /// 执行单个工具并返回打包数据（供串行/并行执行复用）。
  Future<_ToolExecutionData> _executeOneTool({required ToolCall tc}) async {
    final result = await _service.executeToolCallInternal(
      toolCall: tc,
      cancelToken: _token,
      sentinelId: _sentinelId,
      permissionGate: _permissionGate,
    );
    return _ToolExecutionData(
      event: AgentToolResultEvent(
        id: tc.id,
        name: tc.function.name,
        result: result.rawResult,
        status: result.status,
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
        'status': result.status.name,
      },
    );
  }

  /// 并行执行单个工具，受 [semaphore] 限流。
  Future<_ToolExecutionData> _executeParallelOne({
    required ToolCall tc,
    required _AsyncSemaphore semaphore,
  }) async {
    await semaphore.acquire();
    try {
      return await _executeOneTool(tc: tc);
    } finally {
      semaphore.release();
    }
  }

  void _recordFailure(AgentToolResultEvent event) {
    if (event.status == ToolResultStatus.success) {
      return;
    }
    _toolFailures.add(
      ToolFailure(
        toolName: event.name,
        status: event.status,
        message: event.result,
      ),
    );
  }

  String _latestUserTask() {
    for (final message in _messages.reversed) {
      if (message is UserMessage) return '${message.content}';
    }
    return '';
  }
}

/// 单轮迭代的局部状态：LLM 流累积器与"模型主动结束"标志。
///
/// [_AgentLoop._runIteration] 经 [_AgentLoop._streamTurn] 共享累积器,
/// 避免把一轮的临时字段散落在循环类上。
class _TurnState {
  final ChatStreamAccumulator accumulator = ChatStreamAccumulator();

  /// 模型未发起工具调用、主动结束本轮。
  bool done = false;
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

/// 流式累积中的单个 tool_call: id/name/arguments 分片到达。
class _StreamingToolCall {
  String? id;
  String? name;
  String arguments = '';
}

/// 单个工具执行的结果打包。供 [_AgentLoop._executeOneTool] 返回。
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
/// 工具执行内部结果：不进入公开事件流，仅供测试与循环内部复用。
@visibleForTesting
class ToolCallResultInternal {
  final AgentToolResultEvent event;
  final String processedResult;
  final String rawResult;
  final ToolResultStatus status;
  const ToolCallResultInternal({
    required this.event,
    required this.processedResult,
    required this.rawResult,
    required this.status,
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
    required ToolResultStatus status,
  }) = AgentToolResultEvent;

  const factory AgentEvent.iterationComplete({
    required List<Map<String, dynamic>> toolCalls,
    required String content,
  }) = AgentIterationCompleteEvent;

  const factory AgentEvent.done({required String content}) = AgentDoneEvent;

  const factory AgentEvent.turnStart({required int iteration}) =
      AgentTurnStartEvent;

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

  const factory AgentEvent.outcome(AgentRunOutcome outcome) =
      AgentRunOutcomeEvent;
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
  const AgentToolCallArgsEvent({required this.id, required this.delta});
}

class AgentToolResultEvent extends AgentEvent {
  final String id;
  final String name;
  final String result;
  final ToolResultStatus status;
  const AgentToolResultEvent({
    required this.id,
    required this.name,
    required this.result,
    this.status = ToolResultStatus.success,
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

class AgentRunOutcomeEvent extends AgentEvent {
  final AgentRunOutcome outcome;
  const AgentRunOutcomeEvent(this.outcome);
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
