import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/entity/token_usage.dart';

/// 协调层**内部发起**的 run（后台任务完成后的自动汇报）的事件。
///
/// 与 [RunEvent] 的区别只有一个：它没有 `sendMessage` 的调用上下文，所以
/// 必须自带会话 id，前端才知道该更新哪个会话的界面。
class InternalRunEvent {
  const InternalRunEvent(this.chatId, this.event);

  final int chatId;
  final RunEvent event;
}

/// Agent 一次 run 的对外事件契约（UI 无关）。
///
/// GUI 与 TUI 各自消费同一事件流：[RunMessageStored] 等由
/// [AgentRunCoordinator.send] 产出。
sealed class RunEvent {
  const RunEvent();
}

class RunMessageStored extends RunEvent {
  final MessageEntity message;
  const RunMessageStored(this.message);
}

class RunCompactionChanged extends RunEvent {
  final CompactionStep step;
  const RunCompactionChanged(this.step);
}

class RunAssistantAppended extends RunEvent {
  final MessageEntity message;
  const RunAssistantAppended(this.message);
}

class RunMessageUpdated extends RunEvent {
  final MessageEntity message;
  const RunMessageUpdated(this.message);
}

class RunIterationChanged extends RunEvent {
  final int iteration;
  const RunIterationChanged(this.iteration);
}

class RunToolNameChanged extends RunEvent {
  final String? toolName;
  const RunToolNameChanged(this.toolName);
}

class RunUsageChanged extends RunEvent {
  final TokenUsage usage;
  final ChatEntity chat;
  const RunUsageChanged(this.usage, this.chat);
}

class RunOutcomeChanged extends RunEvent {
  final AgentRunOutcome outcome;
  const RunOutcomeChanged(this.outcome);
}

class RunAutoRename extends RunEvent {
  const RunAutoRename();
}

class RunListReload extends RunEvent {
  const RunListReload();
}

class RunError extends RunEvent {
  final String message;
  const RunError(this.message);
}
