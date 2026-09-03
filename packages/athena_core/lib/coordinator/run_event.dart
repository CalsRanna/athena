import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/entity/token_usage.dart';

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
