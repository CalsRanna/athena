import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
      color: widget.value ? colors.sage : colors.checkboxOff,
      width: 2,
    );
    var color = widget.value ? colors.sage : Colors.transparent;
    var boxDecoration = BoxDecoration(
      border: border,
      borderRadius: BorderRadius.circular(4),
      color: color, // Change color when checked
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
    return Icon(HugeIcons.strokeRoundedTick02, color: Colors.white, size: 12);
  }
}
