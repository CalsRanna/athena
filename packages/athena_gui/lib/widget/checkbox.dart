import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Codex 风格勾选框：小圆角方块，选中为反色实心块。
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
  final Function()? onTap;
  final Widget? trailing;
  const AthenaCheckboxGroup({
    super.key,
    required this.checkbox,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      checkbox,
      if (trailing != null) const SizedBox(width: 12),
      if (trailing != null) trailing!,
    ];
    var mouseRegion = MouseRegion(
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var border = Border.all(
      color: widget.value ? colors.surfaceRaised : colors.checkboxOff,
    );
    // 同 menu.dart：不能从 Colors.transparent 插值，否则取消勾选时闪一下深色
    var color = widget.value
        ? colors.surfaceRaised
        : colors.surfaceRaised.withValues(alpha: 0);
    var boxDecoration = BoxDecoration(
      border: border,
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
      color: color,
    );
    var animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: Durations.short2,
      height: 16,
      width: 16,
      child: widget.value ? _buildCheckIcon() : null,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: animatedContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged?.call(!widget.value),
      child: mouseRegion,
    );
  }

  Widget _buildCheckIcon() {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Icon(
      HugeIcons.strokeRoundedTick02,
      color: colors.iconOnRaised,
      size: 11,
    );
  }
}
