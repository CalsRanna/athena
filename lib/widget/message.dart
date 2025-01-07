import 'package:athena/component/button.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:markdown/markdown.dart' as md;

class MessageTile extends StatelessWidget {
  final Message message;
  final void Function()? onResend;
  final Sentinel? sentinel;

  const MessageTile({
    super.key,
    required this.message,
    this.onResend,
    this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return _UserMessage(message: message, onResend: onResend);
    }
    return _AssistantMessage(message: message, sentinel: sentinel);
  }
}

class _AssistantMessage extends StatelessWidget {
  final Message message;
  final Sentinel? sentinel;
  const _AssistantMessage({required this.message, this.sentinel});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 12),
      _buildContent(),
      const SizedBox(width: 12),
      _Copy(onTap: handleCopy),
    ];
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withValues(alpha: 0.95),
    );
    return Container(
      decoration: boxDecoration,
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: row,
    );
  }

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  Widget _buildAvatar() {
    if (sentinel?.avatar.isNotEmpty == true) {
      const textStyle = TextStyle(fontSize: 24, height: 1, color: Colors.white);
      var boxDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF282F32),
      );
      return Container(
        alignment: Alignment.center,
        decoration: boxDecoration,
        height: 36,
        width: 36,
        child: Text(sentinel!.avatar, style: textStyle),
      );
    }
    var image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      height: 36,
      width: 36,
    );
    return ClipOval(child: image);
  }

  Widget _buildContent() {
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minHeight: 36),
      child: _Markdown(message: message),
    );
    return Expanded(child: container);
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
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
    var children = [
      _buildContent(context, element),
      if (multipleLines) _buildCopyButton(element),
    ];
    return Stack(children: children);
  }

  Widget _buildContent(BuildContext context, md.Element element) {
    final multipleLines = element.textContent.split('\n').length > 1;
    var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    if (multipleLines) {
      padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    final width = multipleLines ? double.infinity : null;
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: Theme.of(context).colorScheme.surfaceContainer,
    );
    return Container(
      decoration: boxDecoration,
      padding: padding,
      width: width,
      child: Text(element.textContent.trim(), style: textStyle),
    );
  }

  Widget _buildCopyButton(md.Element element) {
    return Positioned(
      right: 12,
      top: 12,
      child: CopyButton(onTap: () => handleTap(element.textContent)),
    );
  }
}

class _Copy extends StatefulWidget {
  final void Function()? onTap;
  const _Copy({this.onTap});

  @override
  State<_Copy> createState() => _CopyState();
}

class _CopyState extends State<_Copy> {
  bool copied = false;
  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withValues(alpha: 0.25);
    var iconData = HugeIcons.strokeRoundedCopy01;
    if (copied) iconData = HugeIcons.strokeRoundedTick01;
    var icon = HugeIcon(color: color, icon: iconData, size: 16.0);
    const duration = Duration(milliseconds: 200);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: AnimatedSwitcher(duration: duration, child: icon),
    );
  }

  void handleTap() async {
    if (copied) return;
    widget.onTap?.call();
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      copied = false;
    });
  }
}

class _Markdown extends StatelessWidget {
  final Message message;
  final bool supportLatex = true;

  const _Markdown({required this.message});

  @override
  Widget build(BuildContext context) {
    Map<String, MarkdownElementBuilder> builders = {
      'code': _CodeElementBuilder()
    };
    if (supportLatex) builders['latex'] = LatexElementBuilder();
    List<md.BlockSyntax> blockSyntaxes = [LatexBlockSyntax()];
    blockSyntaxes.addAll(md.ExtensionSet.gitHubFlavored.blockSyntaxes);
    final inlineSyntaxes = [LatexInlineSyntax()];
    final extensions = md.ExtensionSet(blockSyntaxes, inlineSyntaxes);
    return MarkdownBody(
      key: ValueKey('markdown-${supportLatex.toString()}'),
      builders: builders,
      data: message.content,
      extensionSet: supportLatex ? extensions : null,
    );
  }
}

class _UserMessage extends StatelessWidget {
  final Message message;
  final void Function()? onResend;
  const _UserMessage({required this.message, this.onResend});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 8),
      _buildContent(),
      const SizedBox(width: 8),
      _buildResendButton(context),
    ];
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: row,
    );
  }

  void handleTap() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  Widget _buildAvatar() {
    const textStyle = TextStyle(fontSize: 14, height: 1);
    var boxDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.95),
    );
    return Container(
      alignment: Alignment.center,
      decoration: boxDecoration,
      height: 36,
      width: 36,
      child: Text('CA', style: textStyle),
    );
  }

  Widget _buildContent() {
    var textStyle = TextStyle(color: Color(0xFFCACACA));
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(minHeight: 36),
      child: Text(message.content, style: textStyle),
    );
    return Expanded(child: container);
  }

  Widget _buildResendButton(BuildContext context) {
    var boxDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
    );
    var container = Container(
      decoration: boxDecoration,
      height: 24,
      padding: const EdgeInsets.all(6),
      width: 24,
      child: Icon(HugeIcons.strokeRoundedRefresh, size: 12),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResend,
      child: container,
    );
  }
}
