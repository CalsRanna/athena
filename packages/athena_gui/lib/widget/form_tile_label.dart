import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

class AthenaFormTileLabel extends StatelessWidget {
  final String title;
  final TextStyle base;
  final Widget? trailing;

  const AthenaFormTileLabel({super.key, required this.title, this.trailing})
    : base = AthenaTextStyle.section;

  const AthenaFormTileLabel.large({
    super.key,
    required this.title,
    this.trailing,
  }) : base = AthenaTextStyle.title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleTextStyle = base.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
      height: 1.4,
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
