import 'package:flutter/material.dart';

class AFormTileLabel extends StatelessWidget {
  final String title;
  final double titleFontSize;
  final Widget? trailing;

  const AFormTileLabel({super.key, required this.title, this.trailing})
      : titleFontSize = 14;

  const AFormTileLabel.large({super.key, required this.title, this.trailing})
      : titleFontSize = 24;

  @override
  Widget build(BuildContext context) {
    var titleTextStyle = TextStyle(
      color: Colors.white,
      fontSize: titleFontSize,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var children = [
      Text(title, style: titleTextStyle),
      trailing ?? const SizedBox(),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }
}
