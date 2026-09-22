/// 工具审批模式：需要审批的工具调用由谁放行。
///
/// GUI composer 左下角、设置 → Agent 与 TUI `/review` 共用同一份设置
/// （`AgentSettings.approvalMode`），下一轮 run 生效。三档都不越过 deny 规则：
/// 明确拒绝永远优先。
enum ApprovalMode {
  /// 手动：需要审批的调用一律弹窗问人。
  manual('manual'),

  /// AI 自动审核：先由当前模型独立审核，拿不准的（以及模型自己标 ask 的）仍问人。
  aiReview('ai_review'),

  /// 所有权限：需要审批的调用直接放行，不问 AI 也不问人。
  bypass('bypass');

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
