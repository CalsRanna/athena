import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:openai_dart/openai_dart.dart';

/// Called at a settled iteration boundary, before the next model request.
typedef ContextCompactionCallback =
    Stream<ContextCompactionUpdate> Function(ContextCompactionRequest request);

class ContextCompactionUpdate {
  const ContextCompactionUpdate(this.step, {this.messages});
  final CompactionStep step;

  /// Present only after the summary and its coverage have been committed.
  final List<ChatMessage>? messages;
}

class ContextCompactionRequest {
  const ContextCompactionRequest({
    required this.messages,
    required this.tools,
    required this.budget,
    required this.outputs,
    required this.cancelToken,
  });

  final List<ChatMessage> messages;
  final List<Tool>? tools;
  final ContextBudget budget;
  final ToolOutputStore outputs;
  final CancelToken cancelToken;
}
