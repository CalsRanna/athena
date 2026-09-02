/// Agent run 的终止原因。
///
/// `completed` 只表示模型主动结束，不等价于任务在语义上成功。
enum AgentRunTermination { completed, maxIterations, cancelled, error }

/// 单次工具调用的结构化结果。
enum ToolResultStatus {
  success,
  invalidArguments,
  blocked,
  executionError,
  modelTruncated,
}

/// 可供 Reflection 使用的工具失败证据。
class ToolFailure {
  final String toolName;
  final ToolResultStatus status;
  final String message;

  const ToolFailure({
    required this.toolName,
    required this.status,
    required this.message,
  });
}

/// 一次 Agent run 的结构化结果。
class AgentRunOutcome {
  final AgentRunTermination termination;
  final int iterations;
  final List<ToolFailure> toolFailures;
  final bool reflectionAttempted;
  final String? error;

  const AgentRunOutcome({
    required this.termination,
    required this.iterations,
    this.toolFailures = const [],
    this.reflectionAttempted = false,
    this.error,
  });
}
