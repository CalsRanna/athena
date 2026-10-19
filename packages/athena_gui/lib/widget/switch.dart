import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 开关：胶囊轨道（34×18）+ 实心圆滑块，尺寸紧凑。
///
/// 开启态用青瓷强调，滑块使用配套前景；关闭态回到中性填充。两态的区分靠
/// 「色相 + 明度」：关闭态是中性的浅轨道，不是一条深色实心条（深色轨道会让
/// 关闭态在视觉重量上追平开启态，状态只靠色相区分，扫视时读不出来）。
class AthenaSwitch extends StatelessWidget {
  final void Function(bool)? onChanged;
  final bool value;
  const AthenaSwitch({super.key, required this.onChanged, required this.value});

  static const _trackWidth = 34.0;
  static const _trackHeight = 18.0;
  static const _pad = 2.0;
  static const _knob = _trackHeight - _pad * 2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final outerDecoration = BoxDecoration(
      color: value ? colors.accent : colors.switchTrackOff,
      borderRadius: BorderRadius.circular(AthenaRadius.pill),
    );
    final innerDecoration = BoxDecoration(
      color: value ? colors.textOnAccent : colors.switchKnob,
      shape: BoxShape.circle,
      // 滑块压在轨道平面上，用最近一档阴影拉开它与轨道的距离（DESIGN.md §5）。
      boxShadow: AthenaShadow.raised(colors.shadow),
    );
    final knob = Container(
      decoration: innerDecoration,
      height: _knob,
      width: _knob,
    );
    final animatedContainer = AnimatedContainer(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: outerDecoration,
      duration: AthenaMotion.hover,
      curve: Curves.easeOut,
      height: _trackHeight,
      padding: const EdgeInsets.all(_pad),
      width: _trackWidth,
      child: knob,
    );
    final mobile = switch (Theme.of(context).platform) {
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
      onTap: () => onChanged?.call(!value),
      child: mouseRegion,
    );
  }
}
