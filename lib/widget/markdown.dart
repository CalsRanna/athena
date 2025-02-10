import 'package:athena/component/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

class AMarkdown extends StatelessWidget {
  final String content;
  final bool supportLatex = true;

  const AMarkdown({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    Map<String, MarkdownElementBuilder> builders = {};
    builders['code'] = _CodeElementBuilder();
    builders['hr'] = _DividerElementBuilder();
    if (supportLatex) builders['latex'] = LatexElementBuilder();
    List<md.BlockSyntax> blockSyntaxes = [];
    blockSyntaxes.addAll(md.ExtensionSet.gitHubFlavored.blockSyntaxes);
    blockSyntaxes.add(LatexBlockSyntax());
    List<md.InlineSyntax> inlineSyntaxes = [];
    inlineSyntaxes.add(LatexInlineSyntax());
    final extensions = md.ExtensionSet(blockSyntaxes, inlineSyntaxes);
    // 不能解析 <think></think>，会吃掉<think>及开头的第一段
    return MarkdownBody(
      builders: builders,
      data: content,
      extensionSet: supportLatex ? extensions : null,
    );
    // return GptMarkdown(
    //   // 引用块解析的时候会报错，开发环境不会灰屏，但是生产环境会
    //   message.content.replaceAll(RegExp(r'>'), '☞'),
    //   // message.content,
    //   codeBuilder: _buildCode,
    //   highlightBuilder: _buildHighlight,
    // );
  }

  void handleTap(String text) {
    final data = ClipboardData(text: text);
    Clipboard.setData(data);
  }

  // Widget _buildCode(
  //   BuildContext context,
  //   String name,
  //   String code,
  //   bool closed,
  // ) {
  //   var borderRadius = BorderRadius.circular(8);
  //   var color = Color(0xFFEAECF0);
  //   var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
  //   var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  //   var textStyle = GoogleFonts.firaCode(fontSize: 12);
  //   var container = Container(
  //     decoration: boxDecoration,
  //     padding: padding,
  //     width: double.infinity,
  //     child: Text(code, style: textStyle),
  //   );
  //   var copyButton = _buildCopyButton(code);
  //   return Stack(children: [container, copyButton]);
  // }

  // Widget _buildCopyButton(String code) {
  //   var button = _CopyButton(onTap: () => handleTap(code), size: 12);
  //   return Positioned(right: 12, top: 12, child: button);
  // }

  // Widget _buildHighlight(BuildContext context, String text, TextStyle style) {
  //   var borderRadius = BorderRadius.circular(4);
  //   var color = Color(0xFFEAECF0);
  //   var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
  //   var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
  //   var textStyle = GoogleFonts.firaCode(fontSize: 12);
  //   return Container(
  //     decoration: boxDecoration,
  //     padding: padding,
  //     child: Text(text, style: textStyle),
  //   );
  // }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  _CodeElementBuilder();

  void handleTap(String text) {
    final data = ClipboardData(text: text);
    Clipboard.setData(data);
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final multipleLines = element.textContent.split('\n').length > 1;
    var borderRadius = BorderRadius.circular(4);
    var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    if (multipleLines) {
      borderRadius = BorderRadius.circular(8);
      padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    final width = multipleLines ? double.infinity : null;
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: Color(0xFFEDEDED),
    );
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var contentText = Padding(
      padding: padding,
      child: Text(element.textContent, style: textStyle),
    );
    var children = [
      if (element.attributes['class'] != null) _buildAttribute(element),
      contentText,
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Container(
      decoration: boxDecoration,
      width: width,
      child: column,
    );
  }

  Container _buildAttribute(md.Element element) {
    var borderRadius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: Color(0xFFE0E0E0),
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var attribute = element.attributes['class'] ?? '';
    var children = [
      Text(attribute.replaceAll('language-', ''), style: textStyle),
      Spacer(),
      CopyButton(onTap: () => handleTap(element.textContent)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: children),
    );
  }
}

class _DividerElementBuilder extends MarkdownElementBuilder {
  _DividerElementBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return const Divider();
  }
}
