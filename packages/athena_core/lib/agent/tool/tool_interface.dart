/// 工具执行模式。
enum ExecutionMode {
  /// 串行执行：每次只执行一个工具。
  sequential,

  /// 并行执行：可与其它 parallel 工具同时执行。
  parallel,
}

/// 工具危险等级，决定权限弹窗行为。
enum ToolRisk {
  /// 只读：无副作用，默认放行，永不弹窗。
  readOnly,

  /// 危险：有副作用（写文件、执行命令），必须弹窗审批。
  dangerous,
}

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema

  /// 执行模式。默认串行，文件读取/搜索/抓取可标记为 parallel。
  ExecutionMode get executionMode => ExecutionMode.sequential;

  /// 本次调用是否可并行执行。默认取 [executionMode]。
  ///
  /// 需要按参数动态判断的工具（如 shell 只读命令可并行、有副作用命令
  /// 必须串行）可覆写此方法。
  bool canExecuteParallel(Map<String, dynamic> args) =>
      executionMode == ExecutionMode.parallel;

  /// 危险等级。默认 dangerous（保守），只读工具需显式覆写为 readOnly。
  ToolRisk get risk => ToolRisk.dangerous;

  /// 执行工具。
  ///
  /// [onUpdate] 可选的进度回调，用于流式产出部分结果（如 shell 实时 stdout）。
  /// 实现应确保回调在工具返回后不再被调用。
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  });
}
