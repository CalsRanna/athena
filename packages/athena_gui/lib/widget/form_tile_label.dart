import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

class AthenaFormTileLabel extends StatelessWidget {
  final String title;
  final double titleFontSize;
  final Widget? trailing;

  const AthenaFormTileLabel({super.key, required this.title, this.trailing})
    : titleFontSize = 14;

  const AthenaFormTileLabel.large({
    super.key,
    required this.title,
    this.trailing,
  }) : titleFontSize = 24;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: titleFontSize,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var children = [
      Expanded(child: Text(title, style: titleTextStyle)),
      trailing ?? const SizedBox(),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }
}
