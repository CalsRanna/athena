import 'package:flutter/material.dart';

class ATag extends StatelessWidget {
  final EdgeInsets padding;
  final bool selected;
  final String text;

  const ATag({super.key, this.selected = false, required this.text})
      : padding = const EdgeInsets.symmetric(horizontal: 36, vertical: 13);
  const ATag.small({super.key, this.selected = false, required this.text})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4);

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: selected ? Color(0xFF161616) : Colors.white,
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
      color: selected ? Color(0xFFE0E0E0) : Color(0xFF161616),
    );
    var innerContainer = AnimatedContainer(
      decoration: innerBoxDecoration,
      duration: const Duration(milliseconds: 300),
      padding: padding,
      child: animatedText,
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
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
