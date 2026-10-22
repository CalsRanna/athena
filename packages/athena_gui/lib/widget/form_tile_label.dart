import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

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
    final colors = context.athenaColors;
    final titleTextStyle = base.copyWith(color: colors.textPrimary);
    final children = [
      Expanded(child: Text(title, style: titleTextStyle)),
      trailing ?? const SizedBox(),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }
}
