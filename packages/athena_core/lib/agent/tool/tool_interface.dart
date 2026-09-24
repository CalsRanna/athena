/// Reserved display metadata, removed before permission checks and execution.
const toolCallDescriptionKey = 'call_description';

const toolApprovalRecommendationKey = 'approval_recommendation';
const toolApprovalReasonKey = 'approval_reason';

/// 引擎注入的会话标识。后台任务按会话归属（不是按 run），因此工具必须
/// 知道这次调用属于哪个会话。injection 发生在权限门之后，也不出现在
/// 展示用的原始参数 JSON 里，模型既看不到也改不了。
const toolChatIdKey = '_chat_id';

/// 引擎注入：本轮 run 不允许启动后台任务。
///
/// 自动汇报回合用它守住边界——汇报回合由任务完成触发，用户并不在场，
/// 让它再启动后台任务会形成「任务→汇报→任务」的无限链。
const toolBackgroundDisabledKey = '_background_disabled';

/// Remove model-authored metadata before rule matching or tool execution.
Map<String, dynamic> toolExecutionArguments(Map<String, dynamic> args) =>
    Map<String, dynamic>.of(args)
      ..remove(toolCallDescriptionKey)
      ..remove(toolApprovalRecommendationKey)
      ..remove(toolApprovalReasonKey);

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

  /// 本次调用是否可并行执行。默认取 [executionMode]。
  ///
  /// 需要按参数动态判断的工具可覆写此方法；shell 工具统一串行。
  bool canExecuteParallel(Map<String, dynamic> args) =>
      executionMode == ExecutionMode.parallel;

  /// 执行工具。
  ///
  /// [onUpdate] 可选的进度回调，用于流式产出部分结果（如 shell 实时 stdout）。
  /// 实现应确保回调在工具返回后不再被调用。
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  });
}

/// 可在 run 停止时主动释放外部资源的工具。
///
/// 单独建模，避免所有短暂的本地工具都被迫实现取消参数。Shell、网络请求等
/// 可能长时间阻塞的工具实现此接口，由 Agent 在执行时传入 run 的取消信号。
abstract interface class CancellableTool {
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
    required Future<void> cancelSignal,
  });
}
