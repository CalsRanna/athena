/// 工具执行模式。
enum ExecutionMode {
  /// 串行执行：每次只执行一个工具。
  sequential,

  /// 并行执行：可与其它 parallel 工具同时执行。
  parallel,
}

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema

  /// 执行模式。默认串行，文件读取/搜索/抓取可标记为 parallel。
  ExecutionMode get executionMode => ExecutionMode.sequential;

  /// 执行工具。
  ///
  /// [onUpdate] 可选的进度回调，用于流式产出部分结果（如 shell 实时 stdout）。
  /// 实现应确保回调在工具返回后不再被调用。
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  });
}
