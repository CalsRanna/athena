import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/schema_validator.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/model/token_usage.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/util/logger_util.dart';
import 'package:flutter/foundation.dart';
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

class AgentService {
  final ChatService _chatService;
  final ToolRegistry _toolRegistry;
  final SkillRegistry? _skillRegistry;

  // ─── 运行时状态 ──────────────────────────────────────────
  @protected
  CancelToken? currentCancelTokenInternal;
  @protected
  Completer<void>? settledInternal;
  @protected
  bool isRunningInternal = false;

  /// 当前是否正在执行 Agent 循环。
  bool get isRunning => isRunningInternal;

  /// 当前运行的取消令牌（可能为 null）。
  CancelToken? get currentCancelToken => currentCancelTokenInternal;

  /// 等待当前运行完成后 resolve 的 Future。
  Future<void>? get settled => settledInternal?.future;

  // ─── 消息注入队列 ───────────────────────────────────────
  final List<ChatMessage> _steerQueue = [];
  final List<ChatMessage> _followUpQueue = [];

  /// 注入一条 steering 消息：在当前轮工具执行完成后、下一轮 LLM 调用前插入。
  void steer(ChatMessage message) {
    _steerQueue.add(message);
  }

  /// 注入一条 followUp 消息：在 Agent 停止后作为新用户输入继续运行。
  void followUp(ChatMessage message) {
    _followUpQueue.add(message);
  }

  /// 清空所有待注入的消息。
  void clearQueues() {
    _steerQueue.clear();
    _followUpQueue.clear();
  }

  AgentService({
    required ChatService chatService,
    required ToolRegistry toolRegistry,
    SkillRegistry? skillRegistry,
  })  : _chatService = chatService,
        _toolRegistry = toolRegistry,
        _skillRegistry = skillRegistry;

  /// 取消当前正在进行的 Agent 循环。
  void abort() {
    currentCancelTokenInternal?.cancel();
  }

  /// 等待当前运行结束（如果正在运行）。
  Future<void> waitForIdle() async {
    await (settledInternal?.future ?? Future.value());
  }

  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
  }) async* {
    if (isRunningInternal) {
      throw StateError('Agent is already processing. Wait for completion or abort first.');
    }

    isRunningInternal = true;
    currentCancelTokenInternal = cancelToken ?? CancelToken();
    settledInternal = Completer<void>();
    final token = currentCancelTokenInternal!;

    var messages = _injectPrompts(baseMessages, skillPrompt, evolutionPrompt);
    _skillRegistry?.clearContext();

    // 构建复合 beforeToolCall：用户 hook → 权限检查
    final compositeBeforeToolCall = _buildCompositeBeforeHook(
      userHook: beforeToolCall,
      permissionService: permissionService,
      onPermission: onPermission,
      cancelToken: token,
    );

    // 构建复合 afterToolCall：用户 hook
    final compositeAfterToolCall = _buildCompositeAfterHook(
      userHook: afterToolCall,
    );

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
          if (_steerQueue.isNotEmpty) {
            final steerMessages = List<ChatMessage>.from(_steerQueue);
            _steerQueue.clear();
            messages.addAll(steerMessages);
          }

          yield AgentEvent.turnStart(iteration: iteration);

        final tools = _buildTools();
        final request = ChatCompletionCreateRequest(
          model: model.modelId,
          messages: messages,
          tools: tools,
        );

        final stream = _chatService.getCompletion(
          chat: chat,
          messages: messages,
          provider: provider,
          model: model,
          tools: request.tools,
        );

        final accumulator = ChatStreamAccumulator();

        await for (final chunk in stream) {
          token.throwIfCancelled();
          accumulator.add(chunk);

          final delta = chunk.firstChoice?.delta;
          if (delta != null) {
            final rc = delta.reasoningContent ?? delta.reasoning;
            if (rc != null && rc.isNotEmpty) {
              yield AgentEvent.reasoning(rc);
            }
          }

          final td = chunk.textDelta;
          if (td != null && td.isNotEmpty) {
            yield AgentEvent.text(td);
          }
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

        // 产出 tool_call 事件
        for (final tc in toolCalls) {
          yield AgentEvent.toolCall(
            id: tc.id,
            name: tc.function.name,
            arguments: tc.function.arguments,
          );
        }

        // 追加 assistant 消息（含 tool_calls）
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

        // 分组：区分 sequential / parallel 工具
        final sequentialCalls = <ToolCall>[];
        final parallelCalls = <ToolCall>[];
        for (final tc in toolCalls) {
          final t = _toolRegistry.get(tc.function.name);
          if (t != null && t.executionMode == ExecutionMode.parallel) {
            parallelCalls.add(tc);
          } else {
            sequentialCalls.add(tc);
          }
        }

        // 串行执行
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

        // 并行执行
        if (parallelCalls.isNotEmpty) {
          for (final tc in parallelCalls) {
            yield AgentEvent.toolExecutionStart(
              id: tc.id,
              name: tc.function.name,
              arguments: tc.function.arguments,
            );
          }

          final parallelFutures = parallelCalls.map((tc) => _executeOneTool(
            tc: tc,
            token: token,
            sentinelId: sentinelId,
            beforeHook: compositeBeforeToolCall,
            afterHook: compositeAfterToolCall,
          ));

          final results = await Future.wait(parallelFutures);

          for (final data in results) {
            yield data.event;
            messages.add(data.toolMessage);
            toolCallDataList.add(data.record);
          }
        }

        yield AgentEvent.iterationComplete(
          toolCalls: toolCallDataList,
          content: accumulator.content,
        );
      }

        // 检查 followUp 消息：有则注入并重启内层循环
        if (_followUpQueue.isNotEmpty) {
          final followUps = List<ChatMessage>.from(_followUpQueue);
          _followUpQueue.clear();
          messages.addAll(followUps);
        } else {
          break; // 无 followUp，退出外层循环
        }
      }
    } finally {
      _skillRegistry?.clearContext();
      isRunningInternal = false;
      currentCancelTokenInternal = null;
      if (settledInternal != null && !settledInternal!.isCompleted) {
        settledInternal!.complete();
      }
      settledInternal = null;
    }
  }

  /// 构建复合 beforeToolCall：用户 hook + 权限检查串联。
  BeforeToolCallHook? _buildCompositeBeforeHook({
    BeforeToolCallHook? userHook,
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

      final ruleMatched =
          permissionService?.check(ctx.name, ctx.args) == true;

      if (!ruleMatched) {
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

  /// 构建复合 afterToolCall：用户 hook。
  AfterToolCallHook? _buildCompositeAfterHook({
    AfterToolCallHook? userHook,
  }) {
    if (userHook == null) return null;

    return (ctx) async {
      return userHook((
        name: ctx.name,
        arguments: ctx.arguments,
        args: ctx.args,
        rawResult: ctx.rawResult,
        processedResult: ctx.processedResult,
      ));
    };
  }

  /// 首轮注入 skill / evolution prompt。
  List<ChatMessage> _injectPrompts(
    List<ChatMessage> base,
    String? skillPrompt,
    String? evolutionPrompt,
  ) {
    var messages = List<ChatMessage>.from(base);
    if (skillPrompt != null && skillPrompt.isNotEmpty) {
      messages = [ChatMessage.system(skillPrompt), ...messages];
    }
    if (evolutionPrompt != null && evolutionPrompt.isNotEmpty) {
      messages = [ChatMessage.system(evolutionPrompt), ...messages];
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

    // afterToolCall hook（含摘要逻辑）
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
    if (!kDebugMode) return;
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

