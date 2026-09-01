import 'dart:convert';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/component/button.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/base64_image.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/component/tool_group_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/message_display_util.dart';
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

class _AssistantMessageRenderData {
  final MessageEntity message;
  final List<MessageEntity> toolMessages;
  final bool loading;
  final bool addBoundarySpacing;

  const _AssistantMessageRenderData({
    required this.message,
    required this.toolMessages,
    required this.loading,
    required this.addBoundarySpacing,
  });
}

class _MessageListRenderItem {
  final MessageEntity message;
  final _AssistantMessageRenderData? assistantData;
  final List<MessageEntity> cardMessages;
  final bool isAssistantCardStart;
  final bool isAssistantCardEnd;
  final bool addCardSpacing;

  const _MessageListRenderItem({
    required this.message,
    this.assistantData,
    this.cardMessages = const [],
    this.isAssistantCardStart = false,
    this.isAssistantCardEnd = false,
    required this.addCardSpacing,
  });

  String get key {
    final identity = message.id ?? identityHashCode(message);
    return assistantData == null ? 'message-$identity' : 'assistant-$identity';
  }
}

/// 整个聊天共用的懒加载消息 Sliver。
///
/// 连续 Assistant 回复仍按原始消息逐项懒构建；每项绘制同色、无间隔的背景
/// 片段，首尾片段分别绘制上/下圆角，视觉上组成一张卡片。这样无需嵌套滚动，
/// 也不会依赖可变高度 Sliver 的估算 scrollExtent。
class MessageCardListSliver extends StatelessWidget {
  final bool loading;
  final List<MessageEntity> messages;
  final SentinelEntity sentinel;
  final EdgeInsetsGeometry padding;
  final void Function(MessageEntity)? onLongPress;
  final void Function(TapUpDetails, MessageEntity)? onSecondaryTapUp;
  final void Function(MessageEntity)? onResend;

  const MessageCardListSliver({
    super.key,
    this.loading = false,
    required this.messages,
    required this.sentinel,
    this.padding = EdgeInsets.zero,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final renderItems = _buildMessageListRenderItems(
      messages,
      loading: loading,
    ).reversed.toList(growable: false);
    final itemIndices = <String, int>{
      for (final (index, item) in renderItems.indexed) item.key: index,
    };
    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: renderItems.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          return itemIndices[key.value];
        },
        itemBuilder: (context, index) {
          final item = renderItems[index];
          Widget child;
          final assistantData = item.assistantData;
          if (assistantData != null) {
            child = _AssistantMessageCardSegment(
              data: assistantData,
              isCardStart: item.isAssistantCardStart,
              isCardEnd: item.isAssistantCardEnd,
              cardMessages: item.cardMessages,
              sentinel: sentinel,
            );
          } else {
            child = MessageListTile(
              message: item.message,
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(item.message),
              onSecondaryTapUp: onSecondaryTapUp == null
                  ? null
                  : (details) => onSecondaryTapUp!(details, item.message),
              onResend: onResend == null ? null : () => onResend!(item.message),
              sentinel: sentinel,
            );
          }
          if (item.addCardSpacing) {
            child = Padding(
              padding: const EdgeInsets.only(top: 12),
              child: child,
            );
          }
          return KeyedSubtree(key: ValueKey(item.key), child: child);
        },
      ),
    );
  }
}

List<_MessageListRenderItem> _buildMessageListRenderItems(
  List<MessageEntity> messages, {
  required bool loading,
}) {
  final cards = buildMessageDisplayCards(messages);
  final result = <_MessageListRenderItem>[];

  for (final (cardIndex, cardMessages) in cards.indexed) {
    final message = cardMessages.first;
    if (message.role != 'assistant') {
      result.add(
        _MessageListRenderItem(message: message, addCardSpacing: cardIndex > 0),
      );
      continue;
    }

    final renderData = _buildAssistantRenderData(
      cardMessages,
      loading: loading && cardIndex == cards.length - 1,
    );
    for (final (itemIndex, data) in renderData.indexed) {
      result.add(
        _MessageListRenderItem(
          message: data.message,
          assistantData: data,
          cardMessages: cardMessages,
          isAssistantCardStart: itemIndex == 0,
          isAssistantCardEnd: itemIndex == renderData.length - 1,
          addCardSpacing: cardIndex > 0 && itemIndex == 0,
        ),
      );
    }
  }

  return result;
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
    final renderData = _buildAssistantRenderData([message], loading: loading);
    return _AssistantMessageCardSegment(
      data: renderData.first,
      isCardStart: true,
      isCardEnd: true,
      cardMessages: [message],
      sentinel: sentinel,
    );
  }
}

class _AssistantMessageCardSegment extends StatelessWidget {
  final _AssistantMessageRenderData data;
  final bool isCardStart;
  final bool isCardEnd;
  final List<MessageEntity> cardMessages;
  final SentinelEntity sentinel;

  const _AssistantMessageCardSegment({
    required this.data,
    required this.isCardStart,
    required this.isCardEnd,
    required this.cardMessages,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        'assistant-card-segment-${data.message.id ?? identityHashCode(data.message)}',
      ),
      decoration: _assistantCardDecoration(
        context,
        isCardStart: isCardStart,
        isCardEnd: isCardEnd,
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        isCardStart ? 12 : 0,
        16,
        isCardEnd ? 16 : 0,
      ),
      child: _AssistantMessageSegment(
        data: data,
        isCardHeader: isCardStart,
        cardMessages: cardMessages,
        sentinel: sentinel,
      ),
    );
  }
}

class _AssistantMessageSegment extends StatelessWidget {
  final _AssistantMessageRenderData data;
  final bool isCardHeader;
  final List<MessageEntity> cardMessages;
  final SentinelEntity sentinel;

  const _AssistantMessageSegment({
    required this.data,
    required this.isCardHeader,
    required this.cardMessages,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCardHeader
            ? _buildAssistantAvatar(context, sentinel)
            : const SizedBox(width: 36),
        const SizedBox(width: 12),
        Expanded(child: _AssistantMessageContent(data: data)),
        _buildAssistantTrailingSpace(),
      ],
    );
    Widget result = isCardHeader
        ? Stack(
            children: [
              row,
              Positioned(
                right: 0,
                child: CopyButton(
                  onTap: () => _copyAssistantMessages(cardMessages),
                ),
              ),
            ],
          )
        : row;
    if (data.addBoundarySpacing) {
      result = Padding(padding: const EdgeInsets.only(top: 12), child: result);
    }
    return result;
  }
}

class _AssistantMessageContent extends StatelessWidget {
  final _AssistantMessageRenderData data;

  const _AssistantMessageContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final message = data.message;
    final children = <Widget>[];
    if (message.reasoningContent.isNotEmpty) {
      children.add(_AssistantMessageListTileThinkingPart(message: message));
    }
    if (message.content.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(AthenaMarkdown(message: message));
    }

    final toolItems = _buildToolItems(data.toolMessages);
    if (toolItems.isNotEmpty) {
      children.add(_buildToolPart(toolItems));
    }
    if (message.reference.isNotEmpty) {
      children.add(_AssistantMessageListTileReferencePart(message: message));
    }
    if (data.loading) {
      children.add(const _AssistantMessageListTileLoadingPart(loading: true));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<ToolGroupCardItem> _buildToolItems(List<MessageEntity> toolMessages) {
    final items = <ToolGroupCardItem>[];
    for (final message in toolMessages) {
      final results = <String, String>{};
      if (message.toolResults.isNotEmpty) {
        try {
          final list = jsonDecode(message.toolResults) as List<dynamic>;
          for (final result in list) {
            results[result['id'] as String] = result['result'] as String;
          }
        } catch (_) {}
      }

      if (message.toolCalls.isEmpty) continue;
      try {
        final calls = jsonDecode(message.toolCalls) as List<dynamic>;
        for (final call in calls) {
          final id = call['id'] as String;
          items.add(
            ToolGroupCardItem(
              id: id,
              toolName: call['name'] as String? ?? '',
              arguments: call['arguments'] as String? ?? '',
              result: results[id],
            ),
          );
        }
      } catch (_) {}
    }
    return items;
  }

  Widget _buildToolPart(List<ToolGroupCardItem> items) {
    if (items.length == 1) {
      final item = items.single;
      return ToolCard(
        key: ValueKey('tool-${item.id}'),
        toolName: item.toolName,
        arguments: item.arguments,
        result: item.result,
      );
    }
    return ToolGroupCard(
      key: ValueKey('tool-group-${items.first.id}'),
      items: items,
    );
  }
}

List<_AssistantMessageRenderData> _buildAssistantRenderData(
  List<MessageEntity> messages, {
  required bool loading,
}) {
  assert(messages.isNotEmpty);
  final toolMessages = List.generate(messages.length, (_) => <MessageEntity>[]);
  int? openToolOwner;

  for (final (index, message) in messages.indexed) {
    final itemLoading = loading && index == messages.length - 1;
    final hasTools = message.toolCalls.isNotEmpty;
    final hasContentBeforeTools =
        message.reasoningContent.isNotEmpty || message.content.isNotEmpty;
    final hasContentAfterTools = message.reference.isNotEmpty || itemLoading;

    if (hasTools) {
      var owner = index;
      if (!hasContentBeforeTools && openToolOwner != null) {
        owner = openToolOwner;
        toolMessages[owner].add(message);
      } else {
        toolMessages[index].add(message);
      }
      openToolOwner = hasContentAfterTools ? null : owner;
      continue;
    }

    // 完全空的占位记录与旧实现一致，不打断跨消息工具组。
    if (hasContentBeforeTools || hasContentAfterTools) {
      openToolOwner = null;
    }
  }

  final result = <_AssistantMessageRenderData>[];
  for (final (index, message) in messages.indexed) {
    final itemLoading = loading && index == messages.length - 1;
    final effectiveTools = toolMessages[index];
    final visible =
        message.reasoningContent.isNotEmpty ||
        message.content.isNotEmpty ||
        effectiveTools.isNotEmpty ||
        message.reference.isNotEmpty ||
        itemLoading;
    if (!visible) continue;

    final toolsMergedIntoPrevious =
        message.toolCalls.isNotEmpty && effectiveTools.isEmpty;
    final firstPartHasLeadingSpacing =
        message.reasoningContent.isEmpty &&
        (message.content.isNotEmpty ||
            effectiveTools.isNotEmpty ||
            message.reference.isNotEmpty ||
            toolsMergedIntoPrevious);
    result.add(
      _AssistantMessageRenderData(
        message: message,
        toolMessages: effectiveTools,
        loading: itemLoading,
        addBoundarySpacing: result.isNotEmpty && !firstPartHasLeadingSpacing,
      ),
    );
  }

  if (result.isEmpty) {
    result.add(
      _AssistantMessageRenderData(
        message: messages.first,
        toolMessages: const [],
        loading: false,
        addBoundarySpacing: false,
      ),
    );
  }
  return result;
}

BoxDecoration _assistantCardDecoration(
  BuildContext context, {
  required bool isCardStart,
  required bool isCardEnd,
}) {
  final colors = Theme.of(context).extension<AthenaColors>()!;
  const radius = Radius.circular(24);
  return BoxDecoration(
    borderRadius: BorderRadius.only(
      topLeft: isCardStart ? radius : Radius.zero,
      topRight: isCardStart ? radius : Radius.zero,
      bottomLeft: isCardEnd ? radius : Radius.zero,
      bottomRight: isCardEnd ? radius : Radius.zero,
    ),
    color: colors.surfaceRaised.withValues(alpha: 0.95),
  );
}

void _copyAssistantMessages(List<MessageEntity> messages) {
  final content = messages
      .map((message) => message.content)
      .where((content) => content.isNotEmpty)
      .join('\n\n');
  Clipboard.setData(ClipboardData(text: content));
}

Widget _buildAssistantAvatar(BuildContext context, SentinelEntity sentinel) {
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

Widget _buildAssistantTrailingSpace() {
  var isDesktop = PlatformUtil.isDesktop;
  return SizedBox(width: isDesktop ? 48 : 24);
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
    if (message.reasoningContent.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTitle(context), _buildContent(context)],
    );
  }

  void updateExpanded() {
    // 思考期间也可点击展开/折叠，实时查看推理进度
    GetIt.instance<ChatViewModel>().updateExpanded(message);
  }

  Widget _buildContent(BuildContext context) {
    if (!message.expanded) return const SizedBox();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: updateExpanded,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 2, 4, 4),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Text(
          message.reasoningContent,
          style: GoogleFonts.firaCode(
            fontSize: 12,
            color: colors.textSecondaryOnRaised,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondaryOnRaised;
    var startedAt = message.reasoningStartedAt;
    var updatedAt = message.reasoningUpdatedAt;
    var duration = updatedAt.difference(startedAt).inMilliseconds / 1000;
    var durationText = 'Thought for ${duration.toStringAsFixed(1)} seconds';
    var text = message.reasoning ? 'Thinking' : durationText;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: updateExpanded,
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: ToolHeaderShimmer(
          active: message.reasoning,
          child: Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedSparkles,
                size: 15,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.firaCode(fontSize: 12, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
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
    // 图片是用户输入内容的一部分，渲染在文字之前
    var children = [if (images.isNotEmpty) gridView, text];
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
