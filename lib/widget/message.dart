import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hugeicons/hugeicons.dart';

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
      _CopyButton(onTap: handleCopy),
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
      // child: Text(message.content),
    );
    return Expanded(child: container);
  }
}

class _CopyButton extends StatefulWidget {
  final void Function()? onTap;
  final double? size;
  const _CopyButton({this.onTap, this.size});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool copied = false;
  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withValues(alpha: 0.25);
    var iconData = HugeIcons.strokeRoundedCopy01;
    if (copied) iconData = HugeIcons.strokeRoundedTick01;
    var icon = HugeIcon(
      color: color,
      icon: iconData,
      size: widget.size ?? 16.0,
    );
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
    return GptMarkdown(
      message.content,
      codeBuilder: _buildCode,
      highlightBuilder: _buildHighlight,
    );
  }

  void handleTap(String text) {
    final data = ClipboardData(text: text);
    Clipboard.setData(data);
  }

  Widget _buildCode(
    BuildContext context,
    String name,
    String code,
    bool closed,
  ) {
    var borderRadius = BorderRadius.circular(8);
    var color = Color(0xFFEAECF0);
    var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var container = Container(
      decoration: boxDecoration,
      padding: padding,
      width: double.infinity,
      child: Text(code, style: textStyle),
    );
    var copyButton = _buildCopyButton(code);
    return Stack(children: [container, copyButton]);
  }

  Widget _buildCopyButton(String code) {
    var button = _CopyButton(onTap: () => handleTap(code), size: 12);
    return Positioned(right: 12, top: 12, child: button);
  }

  Widget _buildHighlight(BuildContext context, String text, TextStyle style) {
    var borderRadius = BorderRadius.circular(4);
    var color = Color(0xFFEAECF0);
    var boxDecoration = BoxDecoration(borderRadius: borderRadius, color: color);
    var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Text(text, style: textStyle),
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
