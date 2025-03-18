import 'dart:io';

import 'package:athena/component/button.dart';
import 'package:athena/schema/translation.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TranslationListTile extends StatelessWidget {
  final bool showSourceText;
  final bool showTargetText;
  final Translation translation;
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
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
    );
    return Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      constraints: BoxConstraints(minHeight: 36),
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
    var children = [
      _buildContent(),
      _buildTrailingSpace(),
    ];
    var messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
    );
    var stackChildren = [
      messageRow,
      Positioned(right: 0, child: CopyButton(onTap: handleCopy)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(16),
      child: Stack(children: stackChildren),
    );
  }

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: text));
  }

  Widget _buildContent() {
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minHeight: 36),
      child: Text(text),
    );
    return Expanded(child: container);
  }

  Widget _buildTrailingSpace() {
    var isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    return SizedBox(width: isDesktop ? 48 : 24);
  }
}
