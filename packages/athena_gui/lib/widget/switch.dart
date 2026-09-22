import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 开关：小圆角矩形轨道（34×18）+ 实心圆滑块，尺寸紧凑。
///
/// 开启态用 [AthenaColors.statusSuccess]（功能绿），关闭态用
/// [AthenaColors.switchTrackOff]（几乎融入画布的深灰）。
class AthenaSwitch extends StatelessWidget {
  final void Function(bool)? onChanged;
  final bool value;
  const AthenaSwitch({super.key, required this.onChanged, required this.value});

  static const _trackWidth = 34.0;
  static const _trackHeight = 18.0;
  static const _knob = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var outerDecoration = BoxDecoration(
      color: value ? colors.statusSuccess : colors.switchTrackOff,
      borderRadius: BorderRadius.circular(AthenaRadius.inline + 2),
    );
    var knob = Container(
      decoration: BoxDecoration(
        color: colors.switchKnob,
        shape: BoxShape.circle,
      ),
      height: _knob,
      width: _knob,
    );
    var animatedContainer = AnimatedContainer(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: outerDecoration,
      duration: const Duration(milliseconds: 120),
      height: _trackHeight,
      padding: const EdgeInsets.all(3),
      width: _trackWidth,
      child: knob,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: animatedContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged?.call(!value),
      child: mouseRegion,
    );
  }
}
