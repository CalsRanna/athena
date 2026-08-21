import 'package:athena_gui/component/button.dart';
import 'package:athena_core/entity/translation_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TranslationListTile extends StatelessWidget {
  final bool showSourceText;
  final bool showTargetText;
  final TranslationEntity translation;
  const TranslationListTile({
    super.key,
    required this.translation,
    this.showSourceText = true,
    this.showTargetText = true,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      if (showSourceText) _SourceText(translation.sourceText),
      if (showSourceText && showTargetText) const SizedBox(height: 4),
      if (showTargetText) _TargetText(translation.targetText),
    ];
    return Column(children: children);
  }
}

class _SourceText extends StatelessWidget {
  final String text;
  const _SourceText(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.border,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: colors.inputBackground.withValues(alpha: 0.6),
    );
    return Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: EdgeInsets.all(16),
      child: Text(text, style: textStyle),
    );
  }
}

class _TargetText extends StatelessWidget {
  final String text;
  const _TargetText(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var children = [
      Expanded(child: Text(text, style: textStyle)),
      SizedBox(width: 16),
    ];
    var messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: colors.surfaceRaised.withValues(alpha: 0.95),
    );
    var stackChildren = [
      messageRow,
      Positioned(right: 0, child: CopyButton(onTap: copyTargetText)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(16),
      child: Stack(children: stackChildren),
    );
  }

  void copyTargetText() {
    Clipboard.setData(ClipboardData(text: text));
  }
}
