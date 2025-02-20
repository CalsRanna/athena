import 'package:athena/component/button.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class MessageListTile extends StatelessWidget {
  final Message message;
  final void Function()? onResend;
  final Sentinel? sentinel;

  const MessageListTile({
    super.key,
    required this.message,
    this.onResend,
    this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return _UserMessageListTile(message: message, onResend: onResend);
    }
    return _AssistantMessageListTile(message: message, sentinel: sentinel);
  }
}

class _AssistantMessageListTile extends StatelessWidget {
  final Message message;
  final Sentinel? sentinel;
  const _AssistantMessageListTile({required this.message, this.sentinel});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 12),
      _buildContent(),
      const SizedBox(width: 48),
    ];
    var message = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withValues(alpha: 0.95),
    );
    var stackChildren = [
      message,
      Positioned(right: 0, child: CopyButton(onTap: handleCopy)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: Stack(children: stackChildren),
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
    var children = [
      _AssistantMessageListTileThinkingPart(message: message),
      if (message.content.isNotEmpty) SizedBox(height: 8),
      AMarkdown(engine: MarkdownEngine.flutter, message: message),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minHeight: 36),
      child: column,
    );
    return Expanded(child: container);
  }
}

class _AssistantMessageListTileThinkingPart extends StatefulWidget {
  final Message message;
  const _AssistantMessageListTileThinkingPart({required this.message});

  @override
  State<_AssistantMessageListTileThinkingPart> createState() =>
      _AssistantMessageListTileThinkingPartState();
}

class _AssistantMessageListTileThinkingPartState
    extends State<_AssistantMessageListTileThinkingPart> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.message.reasoningContent.isEmpty) return const SizedBox();
    var borderRadius = BorderRadius.circular(8);
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: Color(0xFFEDEDED),
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTitle(), _buildContent()],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => expanded = !expanded),
      child: Container(decoration: boxDecoration, child: column),
    );
  }

  Widget _buildContent() {
    if (!expanded) return const SizedBox();
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    return Padding(
      padding: padding,
      child: Text(widget.message.reasoningContent, style: textStyle),
    );
  }

  Widget _buildTitle() {
    var borderRadius = BorderRadius.only(
      bottomLeft: expanded ? Radius.zero : Radius.circular(8),
      bottomRight: expanded ? Radius.zero : Radius.circular(8),
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: Color(0xFFE0E0E0),
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: [Text('Thought', style: textStyle)]),
    );
  }
}

class _UserMessageListTile extends StatelessWidget {
  final Message message;
  final void Function()? onResend;
  const _UserMessageListTile({required this.message, this.onResend});

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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
    var selectableText = SelectableText(
      contextMenuBuilder: (context, editableTextState) => const SizedBox(),
      message.content,
      style: textStyle,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(minHeight: 36),
      child: selectableText,
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
      padding: const EdgeInsets.all(6),
      child: Icon(HugeIcons.strokeRoundedRefresh, size: 12),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResend,
      child: container,
    );
  }
}
