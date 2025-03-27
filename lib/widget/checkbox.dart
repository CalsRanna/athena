import 'package:athena/util/color_util.dart';
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

class _AthenaCheckboxState extends State<AthenaCheckbox> {
  @override
  Widget build(BuildContext context) {
    var border = Border.all(
      color: widget.value ? ColorUtil.FFA7BA88 : ColorUtil.FFD0D5DD,
      width: 2,
    );
    var color = widget.value ? ColorUtil.FFA7BA88 : Colors.transparent;
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
    return const Icon(
      HugeIcons.strokeRoundedTick02,
      color: ColorUtil.FFFFFFFF,
      size: 12,
    );
  }
}
