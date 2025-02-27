import 'dart:convert';
import 'dart:io';

import 'package:athena/component/button.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageListTile extends StatelessWidget {
  final Message message;
  final void Function()? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  final void Function()? onResend;
  final Sentinel sentinel;

  const MessageListTile({
    super.key,
    required this.message,
    this.onLongPress,
    this.onResend,
    this.onSecondaryTapUp,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return _UserMessageListTile(
        message: message,
        onLongPress: onLongPress,
        onResend: onResend,
        onSecondaryTapUp: onSecondaryTapUp,
      );
    }
    return _AssistantMessageListTile(message: message, sentinel: sentinel);
  }
}

class _AssistantMessageListTile extends StatelessWidget {
  final Message message;
  final Sentinel sentinel;
  const _AssistantMessageListTile({
    required this.message,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 12),
      _buildLoading(),
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
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: Stack(children: stackChildren),
    );
  }

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  Widget _buildAvatar() {
    if (sentinel.name != 'Athena' && sentinel.avatar.isNotEmpty) {
      const textStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 20,
        height: 1,
      );
      var text = Text(
        sentinel.avatar,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: textStyle,
        textAlign: TextAlign.center,
      );
      var boxDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: ColorUtil.FF282F32,
      );
      return Container(
        alignment: Alignment.center,
        decoration: boxDecoration,
        height: 36,
        width: 36,
        child: text,
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
      AthenaMarkdown(engine: AthenaMarkdownEngine.flutter, message: message),
      _AssistantMessageListTileReferencePart(message: message),
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

  Widget _buildLoading() {
    var loading = message.content.isEmpty && message.reasoningContent.isEmpty;
    if (!loading) return const SizedBox();
    var indicator = CircularProgressIndicator(strokeWidth: 2);
    var sizedBox = SizedBox(height: 16, width: 16, child: indicator);
    var align = Align(alignment: Alignment.centerLeft, child: sizedBox);
    return SizedBox.square(dimension: 36, child: align);
  }

  Widget _buildTrailingSpace() {
    var isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    return SizedBox(width: isDesktop ? 48 : 24);
  }
}

class _AssistantMessageListTileReferencePart extends StatelessWidget {
  final Message message;
  const _AssistantMessageListTileReferencePart({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.reference.isEmpty) return const SizedBox();
    var references = jsonDecode(message.reference);
    List<Widget> referenceWidgets = [];
    for (var i = 0; i < references.length; i++) {
      referenceWidgets.add(_buildReference(references[i], index: i));
    }
    var children = [Text('References:'), ...referenceWidgets];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FFEDEDED,
    );
    var textStyle = GoogleFonts.firaCode(fontWeight: FontWeight.w500);
    return Container(
      decoration: boxDecoration,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: DefaultTextStyle.merge(style: textStyle, child: column),
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

  Widget _buildReference(Map<String, dynamic> reference, {required int index}) {
    var url = reference['url'];
    var title = reference['title'];
    var textSpan = TextSpan(
      text: title,
      style: const TextStyle(color: Colors.blue),
      recognizer: TapGestureRecognizer()..onTap = () => openLink(url),
    );
    var children = [TextSpan(text: '${index + 1}. '), textSpan];
    return Text.rich(TextSpan(children: children));
  }
}

class _AssistantMessageListTileThinkingPart extends ConsumerWidget {
  final Message message;
  const _AssistantMessageListTileThinkingPart({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.reasoningContent.isEmpty) return const SizedBox();
    var borderRadius = BorderRadius.circular(8);
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: ColorUtil.FFEDEDED,
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTitle(), _buildContent()],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => updateExpanded(ref),
      child: Container(decoration: boxDecoration, child: column),
    );
  }

  void updateExpanded(WidgetRef ref) {
    if (message.reasoning) return;
    ChatViewModel(ref).updateExpanded(message);
  }

  Widget _buildContent() {
    if (!message.expanded) return const SizedBox();
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    return Padding(
      padding: padding,
      child: Text(message.reasoningContent, style: textStyle),
    );
  }

  Widget _buildTitle() {
    var borderRadius = BorderRadius.only(
      bottomLeft: message.expanded ? Radius.zero : Radius.circular(8),
      bottomRight: message.expanded ? Radius.zero : Radius.circular(8),
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: ColorUtil.FFE0E0E0,
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var iconData = HugeIcons.strokeRoundedArrowRight01;
    if (message.expanded) iconData = HugeIcons.strokeRoundedArrowDown01;
    var textStyle = GoogleFonts.firaCode(fontSize: 12);
    var startedAt = message.reasoningStartedAt;
    var updatedAt = message.reasoningUpdatedAt;
    var duration = updatedAt.difference(startedAt).inMilliseconds / 1000;
    var durationText = 'Thought for ${duration.toStringAsFixed(1)} seconds';
    var text = message.reasoning ? 'Thinking' : durationText;
    var children = [
      Text(text, style: textStyle),
      const Spacer(),
      Icon(iconData, size: 16),
    ];
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: children),
    );
  }
}

class _UserMessageListTile extends StatelessWidget {
  final Message message;
  final void Function()? onLongPress;
  final void Function()? onResend;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  const _UserMessageListTile({
    required this.message,
    this.onLongPress,
    this.onResend,
    this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 8),
      _buildContent(context),
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
    // const textStyle = TextStyle(fontSize: 14, height: 1);
    // var boxDecoration = BoxDecoration(
    //   shape: BoxShape.circle,
    //   color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
    // );
    // return Container(
    //   alignment: Alignment.center,
    //   decoration: boxDecoration,
    //   height: 36,
    //   width: 36,
    //   child: Text('CA', style: textStyle),
    // );
    var image = Image.asset(
      'asset/image/avatar.png',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      height: 36,
      width: 36,
    );
    return ClipOval(child: image);
  }

  Widget _buildContent(BuildContext context) {
    var textStyle = TextStyle(color: ColorUtil.FFCACACA);
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(minHeight: 36),
      child: Text(message.content, style: textStyle),
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTapUp,
      child: container,
    );
    return Expanded(child: gestureDetector);
  }

  Widget _buildResendButton(BuildContext context) {
    var boxDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: ColorUtil.FFFFFFFF,
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
