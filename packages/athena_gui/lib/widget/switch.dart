import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 开关：小圆角矩形轨道（34×18）+ 实心圆滑块，尺寸紧凑。
///
/// 开启态用青瓷强调，滑块使用配套前景；关闭态回到中性轨道。
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
    final outerDecoration = BoxDecoration(
      color: value ? colors.accent : colors.switchTrackOff,
      borderRadius: BorderRadius.circular(AthenaRadius.control),
    );
    final knob = Container(
      decoration: BoxDecoration(
        color: value ? colors.textOnAccent : colors.switchKnob,
        shape: BoxShape.circle,
      ),
      height: _knob,
      width: _knob,
    );
    final animatedContainer = AnimatedContainer(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: outerDecoration,
      duration: AthenaMotion.hover,
      height: _trackHeight,
      padding: const EdgeInsets.all(3),
      width: _trackWidth,
      child: knob,
    );
    final mouseRegion = MouseRegion(
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
