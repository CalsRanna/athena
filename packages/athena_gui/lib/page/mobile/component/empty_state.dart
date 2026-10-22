import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 移动端列表空态：图标 + 标题 + 一句说明 + 可选操作。
///
/// 与桌面 `AthenaSettingsEmptyState` 同一语义，但移动端页面是整页列表，
/// 不套设置面板的窄列几何。
class MobileEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  const MobileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final children = [
      Icon(icon, size: AthenaIcon.largeSize, color: colors.textWeak),
      const SizedBox(height: AthenaSpace.md),
      Text(
        title,
        textAlign: TextAlign.center,
        style: AthenaTextStyle.title.copyWith(color: colors.textPrimary),
      ),
      if (hint != null) ...[
        const SizedBox(height: AthenaSpace.sm),
        Text(
          hint!,
          textAlign: TextAlign.center,
          style: AthenaTextStyle.caption.copyWith(color: colors.textSecondary),
        ),
      ],
      if (action != null) ...[const SizedBox(height: AthenaSpace.lg), action!],
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AthenaSpace.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
