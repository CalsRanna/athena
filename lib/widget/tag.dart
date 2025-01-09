import 'package:flutter/material.dart';

class ATag extends StatelessWidget {
  final String text;
  const ATag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      color: Color(0xFF161616),
    );
    var container = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
      child: Text(text, style: textStyle),
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
      child: container,
    );
  }
}
