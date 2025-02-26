import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaSwitch extends StatelessWidget {
  final void Function(bool)? onChanged;
  final bool value;
  const AthenaSwitch({super.key, required this.onChanged, required this.value});

  @override
  Widget build(BuildContext context) {
    var outerShapeDecoration = ShapeDecoration(
      color: value ? ColorUtil.FFA7BA88 : ColorUtil.FFC2C9D1,
      shape: StadiumBorder(),
    );
    var innerBoxDecoration = BoxDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: BoxShape.circle,
    );
    var container = Container(
      decoration: innerBoxDecoration,
      height: 16,
      width: 16,
    );
    var animatedContainer = AnimatedContainer(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: outerShapeDecoration,
      duration: Duration(milliseconds: 100),
      padding: EdgeInsets.all(2),
      width: 36,
      child: container,
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
