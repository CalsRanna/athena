/// 工具审批模式：需要审批的工具调用由谁放行。
///
/// **会话级设置**，存在 `ChatEntity.approvalMode`：GUI composer 左下角与
/// 移动端会话配置、TUI `/review` 改的都是当前会话的档位，下一轮 run 生效。
/// 多对话可同时运行，各按各自的档位处理，不会串台。
///
/// 三档都不越过 deny 规则：明确拒绝永远优先。
enum ApprovalMode {
  /// 手动：需要审批的调用一律弹窗问人。
  manual('manual'),

  /// AI 自动审核：先由当前模型替用户作审批决定，需要用户权衡时再问人。
  aiReview('ai_review'),

  /// 所有权限：需要审批的调用直接放行，不问 AI 也不问人。
  bypass('bypass');

  /// 新会话的默认档。
  ///
  /// 没有做成设置项：它只在 `AgentSettings` 里作为「新会话起点」存在，
  /// 用户可见的档位开关一律在会话上。首次启动时会从旧的全局设置
  /// （见 `AgentSettings.init`）播种一次，此后不再变化。
  static const defaultMode = ApprovalMode.aiReview;

  const ApprovalMode(this.key);

  /// 持久化用的稳定标识。
  final String key;

  static ApprovalMode? fromKey(String? key) {
    for (final mode in values) {
      if (mode.key == key) return mode;
    }
    return null;
  }
}
