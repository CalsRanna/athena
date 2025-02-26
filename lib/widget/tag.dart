import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaTag extends StatelessWidget {
  final EdgeInsets padding;
  final bool selected;
  final String text;

  const AthenaTag({super.key, this.selected = false, required this.text})
      : padding = const EdgeInsets.symmetric(horizontal: 36, vertical: 13);
  const AthenaTag.small({super.key, this.selected = false, required this.text})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4);

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: selected ? ColorUtil.FF161616 : ColorUtil.FFFFFFFF,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var animatedText = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: textStyle,
      child: Text(text),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      color: selected ? ColorUtil.FFE0E0E0 : ColorUtil.FF161616,
    );
    var innerContainer = AnimatedContainer(
      decoration: innerBoxDecoration,
      duration: const Duration(milliseconds: 300),
      padding: padding,
      child: animatedText,
    );
    var colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      ColorUtil.FFFFFFFF.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}
