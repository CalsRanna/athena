/// 单次工具调用的结构化结果。
enum ToolResultStatus {
  success,
  invalidArguments,
  blocked,
  executionError,
  modelTruncated,
}

/// Execution status is independent of model-visible text.
class ToolExecutionResult {
  const ToolExecutionResult.success(this.text, {this.exitCode})
    : status = ToolResultStatus.success;

  const ToolExecutionResult.error(this.text, {this.exitCode})
    : status = ToolResultStatus.executionError;

  final String text;
  final ToolResultStatus status;
  final int? exitCode;
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
