import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/service/messages_state.dart';
import 'package:athena_core/service/responses_state.dart';

/// [AgentService] 一次 run 的**内层**事件契约，由协调层消费。
///
/// 与 [RunEvent] 构成内外两层：[RunEvent] 是面向前端的对外契约，本文件的事件
/// 只在 agent 循环与协调层之间流动，携带更细的流式分片（文本 / 推理增量、
/// 工具参数分片等），由协调层归并成 [RunEvent] 再交给前端。因为两端都不直接
/// 消费它，所以单独成文件而不是挂在 [AgentService] 上。
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
    String? modelResult,
    String? outputId,
    required ToolResultStatus status,
    Map<String, dynamic>? approvalReview,
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

class AgentCompletionDetailsEvent extends AgentEvent {
  final Map<String, dynamic> details;
  const AgentCompletionDetailsEvent(this.details);
}

/// 模型已完整响应带有这些任务通知的请求，协调层据此避免重复汇报。
class AgentBackgroundTasksNotifiedEvent extends AgentEvent {
  final List<String> taskIds;
  const AgentBackgroundTasksNotifiedEvent(this.taskIds);
}

class AgentChatCompletionsStateEvent extends AgentEvent {
  final ChatCompletionsState state;
  const AgentChatCompletionsStateEvent(this.state);
}

class AgentMessagesStateEvent extends AgentEvent {
  final MessagesState state;
  const AgentMessagesStateEvent(this.state);
}

class AgentResponsesStateEvent extends AgentEvent {
  final ResponsesState state;
  const AgentResponsesStateEvent(this.state);
}

class AgentTextEvent extends AgentEvent {
  final String delta;
  const AgentTextEvent(this.delta);
}

class AgentCompactionEvent extends AgentEvent {
  final CompactionStep step;
  const AgentCompactionEvent(this.step);
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
  final String? modelResult;
  final String? outputId;
  final ToolResultStatus status;
  final Map<String, dynamic>? approvalReview;
  const AgentToolResultEvent({
    required this.id,
    required this.name,
    required this.result,
    this.modelResult,
    this.outputId,
    this.status = ToolResultStatus.success,
    this.approvalReview,
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
