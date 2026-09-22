import 'package:athena_core/entity/approval_mode.dart';

/// 三档审批模式在界面上的文案（composer 菜单、设置页共用）。
extension ApprovalModeLabel on ApprovalMode {
  /// 短名：`Manual` / `AI review` / `Bypass permissions`。
  String get label => switch (this) {
    ApprovalMode.manual => 'Manual',
    ApprovalMode.aiReview => 'AI review',
    ApprovalMode.bypass => 'Bypass permissions',
  };

  /// 一句话说明，菜单里放在名字下面。
  String get description => switch (this) {
    ApprovalMode.manual => 'Always ask before running tools',
    ApprovalMode.aiReview =>
      'The model reviews tool calls, asks you when unsure',
    ApprovalMode.bypass => 'Accepts all permissions',
  };
}
