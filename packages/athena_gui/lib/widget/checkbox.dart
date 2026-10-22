import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 勾选框：小圆角方块（[AthenaRadius.inline]），选中为青瓷实心块。
class AthenaCheckbox extends StatefulWidget {
  final void Function(bool)? onChanged;
  final bool value;
  const AthenaCheckbox({
    super.key,
    required this.onChanged,
    required this.value,
  });

  @override
  State<AthenaCheckbox> createState() => _AthenaCheckboxState();
}

class AthenaCheckboxGroup extends StatelessWidget {
  final Widget checkbox;
  final void Function()? onTap;
  final Widget? trailing;
  const AthenaCheckboxGroup({
    super.key,
    required this.checkbox,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      checkbox,
      if (trailing != null) const SizedBox(width: 12),
      ?trailing,
    ];
    final mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: mouseRegion,
    );
  }
}

class _AthenaCheckboxState extends State<AthenaCheckbox> {
  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final border = Border.all(
      color: widget.value ? colors.accent : colors.checkboxOff,
    );
    // 同 menu.dart：不能从 Colors.transparent 插值，否则取消勾选时闪一下深色
    final color = widget.value
        ? colors.accent
        : colors.accent.withValues(alpha: 0);
    final boxDecoration = BoxDecoration(
      border: border,
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
      color: color,
    );
    final animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: AthenaMotion.fast,
      height: 16,
      width: 16,
      child: widget.value ? _buildCheckIcon() : null,
    );
    final mobile = switch (context.athenaPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    final target = mobile
        ? SizedBox.square(
            dimension: AthenaIconButtonSize.touchTarget,
            child: Center(child: animatedContainer),
          )
        : animatedContainer;
    final mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: target,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged?.call(!widget.value),
      child: mouseRegion,
    );
  }

  Widget _buildCheckIcon() {
    final colors = context.athenaColors;
    return Icon(LucideIcons.check, color: colors.textOnAccent, size: 11);
  }
}
