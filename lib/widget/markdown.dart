import 'dart:convert';

import 'package:athena/component/button.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:gpt_markdown/gpt_markdown.dart' as gpt;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class AthenaMarkdown extends StatelessWidget {
  final AthenaMarkdownEngine engine;
  final Message message;

  const AthenaMarkdown({
    super.key,
    this.engine = AthenaMarkdownEngine.flutter,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return switch (engine) {
      AthenaMarkdownEngine.flutter => _FlutterMarkdown(message: message),
      _ => const SizedBox(),
    };
  }
}

enum AthenaMarkdownEngine { flutter, gpt }

class _CallToolRequestBuilder extends MarkdownElementBuilder {
  _CallToolRequestBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FFE0E0E0,
    );
    var text = Text(
      'Call tool: ${element.textContent}',
      style: GoogleFonts.firaCode(fontSize: 12),
    );
    var container = Container(
      decoration: boxDecoration,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      width: double.infinity,
      child: text,
    );
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: container,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }
}

class _CallToolRequestSyntax extends md.InlineSyntax {
  _CallToolRequestSyntax()
      : super(
          r'<CallToolRequest\s+name="(?<name>[^"]+)"\s+arguments="(?<arguments>\{.*\})"\s*><\/CallToolRequest>',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('call_tool_request', match[1]!));
    return true;
  }
}

class _CodeBuilder extends MarkdownElementBuilder {
  _CodeBuilder();

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
      color: ColorUtil.FFEDEDED,
    );
    var textStyle = GoogleFonts.firaCode(fontSize: 12, height: 1.5);
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
    var container = Container(
      decoration: boxDecoration,
      width: width,
      child: column,
    );
    if (multipleLines) return container;
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: container,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }

  Widget _buildAttribute(md.Element element) {
    var borderRadius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: ColorUtil.FFE0E0E0,
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var attribute = element.attributes['class'] ?? '';
    var text = Text(
      attribute.replaceAll('language-', ''),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    var children = [
      Expanded(child: text),
      const SizedBox(width: 12),
      CopyButton(onTap: () => handleTap(element.textContent)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: children),
    );
  }
}

class _FlutterMarkdown extends StatelessWidget {
  final Message message;

  const _FlutterMarkdown({required this.message});

  @override
  Widget build(BuildContext context) {
    Map<String, MarkdownElementBuilder> builders = {};
    builders['code'] = _CodeBuilder();
    builders['latex'] = LatexElementBuilder();
    builders['sup'] = _SupBuilder();
    builders['reference'] = _ReferenceBuilder(onTap: openReference);
    builders['call_tool_request'] = _CallToolRequestBuilder();
    List<md.BlockSyntax> blockSyntaxes = [];
    blockSyntaxes.addAll(md.ExtensionSet.gitHubFlavored.blockSyntaxes);
    blockSyntaxes.add(LatexBlockSyntax());
    List<md.InlineSyntax> inlineSyntaxes = [];
    inlineSyntaxes.addAll(md.ExtensionSet.gitHubFlavored.inlineSyntaxes);
    inlineSyntaxes.add(LatexInlineSyntax());
    inlineSyntaxes.add(_ReferenceSyntax());
    inlineSyntaxes.add(_CallToolRequestSyntax());
    final extensions = md.ExtensionSet(blockSyntaxes, inlineSyntaxes);
    var borderSide = BorderSide(color: ColorUtil.FFC2C2C2, width: 1);
    var markdownStyleSheet = MarkdownStyleSheet(
      blockquoteDecoration: BoxDecoration(border: Border(left: borderSide)),
      horizontalRuleDecoration: BoxDecoration(border: Border(top: borderSide)),
    );
    return MarkdownBody(
      builders: builders,
      data: message.content,
      extensionSet: extensions,
      onTapLink: (text, href, title) => openLink(href),
      styleSheet: markdownStyleSheet,
    );
  }

  Future<void> openLink(String? url) async {
    var uri = Uri.parse(url ?? '');
    if (!(await canLaunchUrl(uri))) {
      AthenaDialog.message('The link is invalid');
      return;
    }
    launchUrl(uri);
  }

  void openReference(int index) {
    try {
      var references = jsonDecode(message.reference);
      var reference = references[index - 1];
      var url = reference['url'];
      openLink(url);
    } catch (error) {
      AthenaDialog.message(error.toString());
    }
  }
}

class _ReferenceBuilder extends MarkdownElementBuilder {
  final void Function(int)? onTap;
  _ReferenceBuilder({this.onTap});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FFEDEDED,
      shape: BoxShape.circle,
    );
    var text = Text(
      element.textContent,
      style: GoogleFonts.firaCode(fontSize: 10),
    );
    var container = Container(
      decoration: boxDecoration,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(4),
      child: text,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap?.call(int.parse(element.textContent)),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: gestureDetector,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }
}

class _ReferenceSyntax extends md.InlineSyntax {
  _ReferenceSyntax() : super(r'\[\[(\d+)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('reference', match[1]!));
    return true;
  }
}

// class _GptMarkdown extends StatelessWidget {
//   final Message message;
//   const _GptMarkdown({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return gpt.GptMarkdown(
//       message.content,
//       codeBuilder: _buildCode,
//       highlightBuilder: _buildHighlight,
//     );
//   }

//   void handleTap(String text) {
//     final data = ClipboardData(text: text);
//     Clipboard.setData(data);
//   }

//   Widget _buildAttribute(String attribute, String code) {
//     var borderRadius = BorderRadius.only(
//       topLeft: Radius.circular(8),
//       topRight: Radius.circular(8),
//     );
//     var boxDecoration = BoxDecoration(
//       borderRadius: borderRadius,
//       color: ColorUtil.FFE0E0E0,
//     );
//     var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
//     var textStyle = GoogleFonts.firaCode(fontSize: 12);
//     var children = [
//       Text(attribute.replaceAll('language-', ''), style: textStyle),
//       Spacer(),
//       CopyButton(onTap: () => handleTap(code)),
//     ];
//     return Container(
//       decoration: boxDecoration,
//       padding: padding,
//       child: Row(children: children),
//     );
//   }

//   Widget _buildCode(
//     BuildContext context,
//     String name,
//     String code,
//     bool closed,
//   ) {
//     var borderRadius = BorderRadius.circular(8);
//     var color = ColorUtil.FFEAECF0;
//     var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
//     var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
//     var textStyle = GoogleFonts.firaCode(fontSize: 12);
//     var children = [
//       _buildAttribute(name, code),
//       Padding(padding: padding, child: Text(code, style: textStyle)),
//     ];
//     var column = Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: children,
//     );
//     return Container(
//       decoration: boxDecoration,
//       width: double.infinity,
//       child: column,
//     );
//   }

//   Widget _buildHighlight(BuildContext context, String text, TextStyle style) {
//     var borderRadius = BorderRadius.circular(4);
//     var color = ColorUtil.FFEAECF0;
//     var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
//     var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
//     var textStyle = GoogleFonts.firaCode(fontSize: 12);
//     return Container(
//       decoration: boxDecoration,
//       padding: padding,
//       child: Text(text, style: textStyle),
//     );
//   }
// }

class _SupBuilder extends MarkdownElementBuilder {
  _SupBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FFEDEDED,
      shape: BoxShape.circle,
    );
    var text = Text(
      element.textContent,
      style: GoogleFonts.firaCode(fontSize: 10),
    );
    var container = Container(
      decoration: boxDecoration,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(4),
      child: text,
    );
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: container,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }
}
