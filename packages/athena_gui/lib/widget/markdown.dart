import 'dart:convert';

import 'package:athena_gui/component/button.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class AthenaMarkdown extends StatelessWidget {
  final MessageEntity message;

  const AthenaMarkdown({super.key, required this.message});

  @override
  Widget build(BuildContext context) => _FlutterMarkdown(message: message);
}

class _CallToolRequestBuilder extends MarkdownElementBuilder {
  _CallToolRequestBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.container),
      color: colors.cardHeader,
    );
    var text = Text(
      'Call tool: ${element.textContent}',
      style: athenaMono(fontSize: 12, color: colors.textOnCode),
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

class _InlineCodeBuilder extends MarkdownElementBuilder {
  _InlineCodeBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AthenaRadius.inline),
        color: colors.codeBackground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        element.textContent,
        style: athenaMono(fontSize: 12, height: 1.5, color: colors.textOnCode),
      ),
    );
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: container,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder();

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
    final elementChildren = element.children;
    if (elementChildren == null ||
        elementChildren.length != 1 ||
        elementChildren.single is! md.Element ||
        (elementChildren.single as md.Element).tag != 'code') {
      return null;
    }
    final codeElement = elementChildren.single as md.Element;
    final rawText = codeElement.textContent;
    final displayText = rawText.endsWith('\n')
        ? rawText.substring(0, rawText.length - 1)
        : rawText;
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 无边框：代码块靠 codeBackground 与页面底色的差自成一层，
    // header 再用 cardHeader 提亮一档划分标题与正文（与 Claude 一致）。
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.container),
      color: colors.codeBackground,
    );
    var textStyle = athenaMono(height: 1.5, color: colors.textOnCode);
    var contentText = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(displayText, style: textStyle),
    );
    var children = [
      _buildHeader(context, codeElement, displayText),
      contentText,
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var container = Container(
      key: const ValueKey('markdown-code-block'),
      decoration: boxDecoration,
      // 裁剪内层背景（语言标签行等），避免从圆角处漏出背景色
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      child: column,
    );
    return container;
  }

  Widget _buildHeader(
    BuildContext context,
    md.Element element,
    String displayText,
  ) {
    var borderRadius = BorderRadius.only(
      topLeft: Radius.circular(AthenaRadius.container),
      topRight: Radius.circular(AthenaRadius.container),
    );
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: colors.cardHeader,
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = athenaMono(fontSize: 12, color: colors.textOnCode);
    final language =
        element.attributes['class']?.replaceFirst('language-', '') ??
        'plain text';
    var text = Text(
      language,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    // header 左端是"这是什么"（图标 + 语言标签），右端是"能对它做什么"（复制）
    var icon = HugeIcon(
      icon: HugeIcons.strokeRoundedCode,
      size: 12,
      color: colors.textOnCode,
    );
    // CopyButton 的图标按传入色 40% 透明度渲染。默认取色 textOnRaised 在浅色
    // 主题下是纯白，落在近白的语言条上等于隐形；这里显式用代码面上的正文色。
    var copyButton = Tooltip(
      message: 'Copy',
      child: CopyButton(
        color: colors.textOnCode,
        onTap: () => handleTap(displayText),
      ),
    );
    var children = [
      icon,
      const SizedBox(width: 6),
      Expanded(child: text),
      const SizedBox(width: 12),
      copyButton,
    ];
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: children),
    );
  }
}

bool _hasClass(md.Element element, String className) {
  final classes = element.attributes['class']?.split(RegExp(r'\s+'));
  return classes?.contains(className) ?? false;
}

class _FootnoteBackrefBuilder extends MarkdownElementBuilder {
  final void Function(String?)? onTap;

  _FootnoteBackrefBuilder({this.onTap});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (!_hasClass(element, 'footnote-backref')) return null;

    final colors = Theme.of(context).extension<AthenaColors>()!;
    var button = Tooltip(
      message: 'Back to reference',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap?.call(element.attributes['href']),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.cardHeader,
              borderRadius: BorderRadius.circular(AthenaRadius.inline),
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 12,
              color: colors.textSecondaryOnCode,
            ),
          ),
        ),
      ),
    );
    var widgetSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: button,
    );
    return RichText(text: TextSpan(children: [widgetSpan]));
  }
}

class _FootnotesMarkdownBody extends MarkdownBody {
  final bool hasFootnotes;
  final AthenaColors colors;

  const _FootnotesMarkdownBody({
    required super.data,
    required super.builders,
    required super.extensionSet,
    required super.onTapLink,
    required super.styleSheet,
    required this.hasFootnotes,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    final content = children ?? const <Widget>[];
    if (!hasFootnotes || content.isEmpty) {
      return super.build(context, content);
    }

    final footnotes = Container(
      key: const ValueKey('markdown-footnotes'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      // 与代码块同壳：同底、同圆角、同样不描边。头部用 cardHeader 提亮一档
      decoration: BoxDecoration(
        color: colors.codeBackground,
        borderRadius: BorderRadius.circular(AthenaRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: colors.cardHeader,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // 头部只有一行标签，与代码块的语言标签同规格
            child: Text(
              'Footnotes',
              style: athenaMono(fontSize: 12, color: colors.textOnCode),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content.last,
          ),
        ],
      ),
    );
    return super.build(context, [
      ...content.take(content.length - 1),
      footnotes,
    ]);
  }
}

class _FlutterMarkdown extends StatelessWidget {
  final MessageEntity message;

  const _FlutterMarkdown({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AthenaColors>()!;
    final base = MarkdownStyleSheet.fromTheme(theme);
    Map<String, MarkdownElementBuilder> builders = {};
    builders['pre'] = _CodeBlockBuilder();
    builders['code'] = _InlineCodeBuilder();
    builders['a'] = _FootnoteBackrefBuilder(onTap: openLink);
    builders['latex'] = LatexElementBuilder(
      textStyle: base.p?.copyWith(color: colors.markdownMath),
    );
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
    final hasFootnotes = _hasFootnoteSection(message.content, extensions);
    var borderSide = BorderSide(color: colors.border, width: 1);
    // 正文样式：助手消息直接坐在页面底色上，正文用页面族文字色。
    // 字号 / 行高取 Claude 的 `--cds-font-size-prose`(15) 与
    // `--cds-leading-prose`(22)——消息正文比 UI 正文（body 14）再大一档，
    // 行高是绝对行盒 22，换算成比例 1.4667。
    var body = base.p?.copyWith(
      color: colors.textPrimary,
      fontSize: AthenaFontSize.prose,
      height: AthenaFontSize.proseHeight,
    );
    // 标题与正文同号、同行高、同字族，只以加粗区分层级：
    // 层级交给字重与间距，不靠放大字号（见 DESIGN.md「Principles」）
    var heading = body?.copyWith(fontWeight: FontWeight.bold);
    // 以 Theme 为基底，覆盖文字/链接/代码色为品牌语义色，
    // 避免 flutter_markdown 默认的硬编码 Colors.blue 链接与深色文字。
    var markdownStyleSheet = base.copyWith(
      a: base.a?.copyWith(
        color: colors.markdownLink,
        fontWeight: FontWeight.w500,
      ),
      del: base.del?.copyWith(
        color: colors.markdownStrikethrough,
        decoration: TextDecoration.lineThrough,
        decorationColor: colors.markdownStrikethrough,
      ),
      p: body,
      code: base.code?.copyWith(color: colors.textOnCode),
      h1: heading,
      h2: heading,
      h3: heading,
      h4: heading,
      h5: heading,
      h6: heading,
      blockquote: base.blockquote?.copyWith(color: colors.textPrimary),
      img: base.img?.copyWith(color: colors.textPrimary),
      listBullet: base.listBullet?.copyWith(color: colors.textPrimary),
      tableHead: base.tableHead?.copyWith(color: colors.textPrimary),
      tableBody: base.tableBody?.copyWith(color: colors.textPrimary),
      blockquoteDecoration: BoxDecoration(border: Border(left: borderSide)),
      horizontalRuleDecoration: BoxDecoration(border: Border(top: borderSide)),
      tableBorder: TableBorder.all(color: colors.border),
      // 多行代码块（fenced code block）背景：覆盖 flutter_markdown 默认的
      // cardColor，保持代码块为局部浅底（自带深色文字，自成对比）
      codeblockDecoration: BoxDecoration(
        color: colors.codeBackground,
        borderRadius: BorderRadius.circular(AthenaRadius.container),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      // 块间距取 Claude 的 `--cds-gap-xs`(6)：实测相邻段落行距 ≈ 28
      // = 行盒 22 + 段距 6。flutter_markdown 默认 8 会偏松。
      blockSpacing: 6,
    );
    return _FootnotesMarkdownBody(
      builders: builders,
      colors: colors,
      data: message.content,
      extensionSet: extensions,
      hasFootnotes: hasFootnotes,
      onTapLink: (text, href, title) => openLink(href),
      styleSheet: markdownStyleSheet,
    );
  }

  bool _hasFootnoteSection(String data, md.ExtensionSet extensions) {
    final hasDefinition = RegExp(
      r'^[ ]{0,3}\[\^[^\] \r\n\t]+\]:',
      multiLine: true,
    ).hasMatch(data);
    if (!hasDefinition) return false;

    final document = md.Document(extensionSet: extensions, encodeHtml: false);
    final nodes = document.parseLines(const LineSplitter().convert(data));
    if (nodes.isEmpty) return false;
    final last = nodes.last;
    return last is md.Element &&
        last.tag == 'section' &&
        _hasClass(last, 'footnotes');
  }

  Future<void> openLink(String? url) async {
    var uri = Uri.parse(url ?? '');
    if (!(await canLaunchUrl(uri))) {
      AthenaDialog.warning('The link is invalid');
      return;
    }
    launchUrl(uri);
  }

  void openReference(int index) {
    try {
      var references = jsonDecode(message.reference);
      var reference = references[index - 1];
      var url = reference['url'];
      openLink(url as String?);
    } catch (error) {
      AthenaDialog.error(error.toString());
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      color: colors.codeBackground,
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
    );
    var text = Text(
      element.textContent,
      style: athenaMono(fontSize: 10, color: colors.textOnCode),
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

class _SupBuilder extends MarkdownElementBuilder {
  _SupBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      color: colors.codeBackground,
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
    );
    var text = Text(
      element.textContent,
      style: athenaMono(fontSize: 10, color: colors.textOnCode),
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
