import 'package:flutter/material.dart';

class AFormTileLabel extends StatelessWidget {
  final String title;
  const AFormTileLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    return Text(title, style: textStyle);
  }
}
