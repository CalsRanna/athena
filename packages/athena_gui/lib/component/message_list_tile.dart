import 'dart:convert';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/component/button.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/base64_image.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageListTile extends StatelessWidget {
  final bool loading;
  final MessageEntity message;
  final void Function()? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  final void Function()? onResend;
  final SentinelEntity sentinel;

  const MessageListTile({
    super.key,
    this.loading = false,
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
    if (message.role == 'tool') {
      return _ToolMessageListTile(message: message);
    }
    return _AssistantMessageListTile(
      loading: loading,
      message: message,
      sentinel: sentinel,
    );
  }
}

class _AssistantMessageListTile extends StatelessWidget {
  final bool loading;
  final MessageEntity message;
  final SentinelEntity sentinel;
  const _AssistantMessageListTile({
    this.loading = false,
    required this.message,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(context),
      const SizedBox(width: 12),
      _buildContent(context),
      _buildTrailingSpace(),
    ];
    var messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // AGENT 消息卡片为浅底（两种模式下保持白色），文字用深色（textOnRaised）
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: colors.surfaceRaised.withValues(alpha: 0.95),
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

  Widget _buildAvatar(BuildContext context) {
    if (sentinel.name != 'Athena' && sentinel.avatar.isNotEmpty) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      final textStyle = TextStyle(
        color: colors.textPrimary,
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
        color: colors.avatarBackground,
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

  Widget _buildContent(BuildContext context) {
    final toolCards = _buildToolCards();

    var children = [
      _AssistantMessageListTileThinkingPart(message: message),
      if (message.content.isNotEmpty) SizedBox(height: 8),
      AthenaMarkdown(message: message),
      ...toolCards,
      _AssistantMessageListTileReferencePart(message: message),
      _AssistantMessageListTileLoadingPart(loading: loading),
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

  List<Widget> _buildToolCards() {
    final cards = <Widget>[];

    Map<String, String> results = {};
    if (message.toolResults.isNotEmpty) {
      try {
        final list = jsonDecode(message.toolResults) as List<dynamic>;
        for (final r in list) {
          results[r['id'] as String] = r['result'] as String;
        }
      } catch (_) {}
    }

    if (message.toolCalls.isNotEmpty) {
      try {
        final calls = jsonDecode(message.toolCalls) as List<dynamic>;
        for (final call in calls) {
          final id = call['id'] as String;
          cards.add(
            ToolCard(
              toolName: call['name'] as String? ?? '',
              arguments: call['arguments'] as String? ?? '',
              result: results[id],
            ),
          );
        }
      } catch (_) {}
    }

    return cards;
  }

  Widget _buildTrailingSpace() {
    var isDesktop = PlatformUtil.isDesktop;
    return SizedBox(width: isDesktop ? 48 : 24);
  }
}

class _AssistantMessageListTileLoadingPart extends StatelessWidget {
  final bool loading;
  const _AssistantMessageListTileLoadingPart({required this.loading});

  @override
  Widget build(BuildContext context) {
    if (!loading) return const SizedBox();
    var indicator = CircularProgressIndicator(strokeWidth: 1);
    var sizedBox = SizedBox(height: 12, width: 12, child: indicator);
    var align = Align(alignment: Alignment.centerLeft, child: sizedBox);
    return SizedBox.square(dimension: 28, child: align);
  }
}

class _AssistantMessageListTileReferencePart extends StatelessWidget {
  final MessageEntity message;
  const _AssistantMessageListTileReferencePart({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.reference.isEmpty) return const SizedBox();
    try {
      final decoded = jsonDecode(message.reference);
      final references = decoded is List ? decoded : const <dynamic>[];
      List<Widget> referenceWidgets = [];
      for (var i = 0; i < references.length; i++) {
        final reference = references[i];
        if (reference is! Map<String, dynamic>) continue;
        referenceWidgets.add(_buildReference(context, reference, index: i));
      }
      var children = [Text('References:'), ...referenceWidgets];
      var column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: children,
      );
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var boxDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colors.divider,
      );
      var textStyle = GoogleFonts.firaCode(
        fontWeight: FontWeight.w500,
        color: colors.textOnRaised,
      );
      return Container(
        decoration: boxDecoration,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: DefaultTextStyle.merge(style: textStyle, child: column),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Future<void> openLink(String? url) async {
    var uri = Uri.parse(url ?? '');
    if (!(await canLaunchUrl(uri))) {
      AthenaDialog.warning('The link is invalid');
      return;
    }
    launchUrl(uri);
  }

  Widget _buildReference(
    BuildContext context,
    Map<String, dynamic> reference, {
    required int index,
  }) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var url = reference['url'] as String?;
    var title = reference['title'] as String?;
    var textSpan = TextSpan(
      text: title,
      style: TextStyle(color: colors.teal),
      recognizer: TapGestureRecognizer()..onTap = () => openLink(url),
    );
    var children = [TextSpan(text: '${index + 1}. '), textSpan];
    return Text.rich(TextSpan(children: children));
  }
}

class _AssistantMessageListTileThinkingPart extends StatelessWidget {
  final MessageEntity message;
  const _AssistantMessageListTileThinkingPart({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (message.reasoningContent.isEmpty) return const SizedBox();
    var borderRadius = BorderRadius.circular(8);
    // 正文区底色比 header 略浅，保持层次（与 markdown 代码块一致）
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: colors.codeBackground,
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTitle(context), _buildContent(context)],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: updateExpanded,
      child: Container(decoration: boxDecoration, child: column),
    );
  }

  void updateExpanded() {
    // 思考期间也可点击展开/折叠，实时查看推理进度
    GetIt.instance<ChatViewModel>().updateExpanded(message);
  }

  Widget _buildContent(BuildContext context) {
    if (!message.expanded) return const SizedBox();
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = GoogleFonts.firaCode(
      fontSize: 12,
      color: colors.textOnRaised,
    );
    return Padding(
      padding: padding,
      child: Text(message.reasoningContent, style: textStyle),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var borderRadius = BorderRadius.only(
      bottomLeft: message.expanded ? Radius.zero : Radius.circular(8),
      bottomRight: message.expanded ? Radius.zero : Radius.circular(8),
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      color: colors.cardHeader,
    );
    var padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    var iconData = HugeIcons.strokeRoundedArrowRight01;
    if (message.expanded) iconData = HugeIcons.strokeRoundedArrowDown01;
    var textStyle = GoogleFonts.firaCode(
      fontSize: 12,
      color: colors.textOnRaised,
    );
    var startedAt = message.reasoningStartedAt;
    var updatedAt = message.reasoningUpdatedAt;
    var duration = updatedAt.difference(startedAt).inMilliseconds / 1000;
    var durationText = 'Thought for ${duration.toStringAsFixed(1)} seconds';
    var text = message.reasoning ? 'Thinking' : durationText;
    // 状态指示与 ToolCard 对齐：思考中 spinner，完成后绿色对勾
    const doneColor = Color(0xFF8AA371);
    var children = [
      Icon(
        HugeIcons.strokeRoundedSparkles,
        size: 15,
        color: colors.textOnRaised,
      ),
      SizedBox(width: 8),
      // 思考时长文案可能撑满标题行，超出时省略而非溢出
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
      if (message.reasoning)
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.textOnRaised,
          ),
        )
      else
        Icon(HugeIcons.strokeRoundedTick02, size: 15, color: doneColor),
      const SizedBox(width: 4),
      Icon(iconData, size: 16, color: colors.textOnRaised),
    ];
    return Container(
      decoration: boxDecoration,
      padding: padding,
      child: Row(children: children),
    );
  }
}

class _ToolMessageListTile extends StatelessWidget {
  final MessageEntity message;
  const _ToolMessageListTile({required this.message});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(context),
      const SizedBox(width: 12),
      _buildContent(context),
      _buildTrailingSpace(),
    ];
    var messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: messageRow,
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var hugeIcon = Icon(
      HugeIcons.strokeRoundedTools,
      color: colors.textPrimary,
      size: 20,
    );
    var boxDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: colors.avatarBackground,
    );
    return Container(
      alignment: Alignment.center,
      decoration: boxDecoration,
      height: 36,
      width: 36,
      child: hugeIcon,
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 工具消息没有工具名可用（MessageEntity 无 tool_call_id），
    // 内容以浅灰代码块样式呈现，与 ToolCard 展开区呼应。
    var textStyle = GoogleFonts.firaCode(
      fontSize: 12,
      color: colors.textOnRaised,
      height: 1.6,
    );
    var text = Text(message.content, style: textStyle);
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: text,
      ),
    );
  }

  Widget _buildTrailingSpace() {
    var isDesktop = PlatformUtil.isDesktop;
    return SizedBox(width: isDesktop ? 48 : 24);
  }
}

class _UserMessageListTile extends StatelessWidget {
  final MessageEntity message;
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

  Widget _buildAvatar() {
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 用户消息为正文级别，用主题化正文色（浅色模式下近黑）
    var textStyle = TextStyle(color: colors.textPrimary);
    var text = Text(message.content, style: textStyle);
    var images = message.imageUrls.isNotEmpty
        ? message.imageUrls.split(',')
        : <String>[];
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 9,
    );
    var gridView = GridView.builder(
      gridDelegate: delegate,
      // 以 base64 为 key：同一网格位置的元素在不同消息间复用时，
      // 避免渲染出上一条消息的图片
      itemBuilder: (context, index) => DesktopBase64Image(
        key: ValueKey(images[index]),
        base64: images[index],
        fit: BoxFit.cover,
        width: double.infinity,
      ),
      itemCount: images.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
    );
    var children = [text, if (images.isNotEmpty) gridView];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(minHeight: 36),
      child: column,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: colors.surfaceRaised,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(6),
      child: Icon(
        HugeIcons.strokeRoundedRefresh,
        size: 12,
        color: colors.iconOnRaised,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResend,
      child: container,
    );
  }
}
