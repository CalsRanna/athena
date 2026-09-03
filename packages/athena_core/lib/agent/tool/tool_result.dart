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
