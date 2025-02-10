import 'package:flutter/material.dart';

class AFormTileLabel extends StatelessWidget {
  final double fontSize;
  final String title;
  const AFormTileLabel({super.key, required this.title}) : fontSize = 14;
  const AFormTileLabel.large({super.key, required this.title}) : fontSize = 24;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    return Text(title, style: textStyle);
  }
}
