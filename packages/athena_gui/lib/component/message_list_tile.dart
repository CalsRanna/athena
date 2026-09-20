import 'dart:convert';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/component/button.dart';
import 'package:athena_gui/component/compaction_card.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/base64_image.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/component/reasoning_card.dart';
import 'package:athena_gui/component/step_group_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MessageListRenderItem {
  final MessageEntity message;

  /// 该消息在助手卡里的布局；非空表示这一项是助手卡内的一段。
  final AssistantMessageLayout? layout;

  /// 该段所属整卡的消息（只有卡片头用它做"复制整轮回复"的载荷）。
  final List<MessageEntity> cardMessages;

  /// 是否为整卡的第一段 / 最后一段：卡片级上下内边距分别落在它们身上。
  final bool isCardHeader;
  final bool isCardTail;

  /// 与上一张卡之间的间距，只加在整卡的第一段上。
  final bool addCardSpacing;

  const _MessageListRenderItem({
    required this.message,
    this.layout,
    this.cardMessages = const [],
    this.isCardHeader = false,
    this.isCardTail = false,
    required this.addCardSpacing,
  });

  String get key {
    final identity = message.id ?? identityHashCode(message);
    return layout == null ? 'message-$identity' : 'assistant-card-$identity';
  }
}

/// 整个聊天共用的懒加载消息 Sliver。
///
/// **每条消息各占一个列表项**：视口外的消息不会被构建、也不参与布局，因此无论
/// 一轮回复里有多少条消息，每帧成本都只与视口内可见的消息数有关。
///
/// 助手消息不再绘制卡片底板。历史上"整卡一个 item + 只画一次背景"是为了消除
/// 相邻同色半透明底板在非整数像素边界上叠加不满造成的 1 像素接缝；代价则是
/// 视口碰到整卡就要构建并逐帧遍历整卡内容（实测流式增量随卡内消息数线性增长，
/// n=400 时约 369ms/帧，而逐消息一项恒为 4-5ms）。既然不要底板，接缝问题与
/// 该约束一并消失（成因与回归见 `test/widget/card_seam_mechanism_test.dart`）。
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
    );
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
          final layout = item.layout;
          Widget child;
          if (layout != null) {
            child = _AssistantMessageItem(
              layout: layout,
              cardMessages: item.cardMessages,
              isCardHeader: item.isCardHeader,
              isCardTail: item.isCardTail,
              sentinel: sentinel,
            );
          } else {
            child = MessageListTile(
              message: item.message,
              loading: loading && item.message.id == messages.last.id,
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
    if (!isAssistantCardMessage(message)) {
      result.add(
        _MessageListRenderItem(message: message, addCardSpacing: cardIndex > 0),
      );
      continue;
    }

    final layouts = buildAssistantMessageLayouts(
      cardMessages,
      loading: loading && cardIndex == cards.length - 1,
    );
    if (layouts.isEmpty) continue;
    for (final (index, layout) in layouts.indexed) {
      result.add(
        _MessageListRenderItem(
          message: layout.message,
          layout: layout,
          cardMessages: cardMessages,
          isCardHeader: index == 0,
          isCardTail: index == layouts.length - 1,
          addCardSpacing: cardIndex > 0 && index == 0,
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
    final layouts = buildAssistantMessageLayouts([message], loading: loading);
    if (layouts.isEmpty) return const SizedBox.shrink();
    return _AssistantMessageItem(
      layout: layouts.first,
      cardMessages: [message],
      isCardHeader: true,
      isCardTail: true,
      sentinel: sentinel,
    );
  }
}

/// 助手卡内的一段消息。
///
/// 卡片没有底板，因此这里只负责卡片级内边距：上内边距落在整卡第一段、下内边距
/// 落在整卡最后一段，中间各段之间零间距（段本身仍连续排布，回归见
/// `test/widget/step_group_card_test.dart`、`test/widget/compaction_card_test.dart`）。
class _AssistantMessageItem extends StatelessWidget {
  final AssistantMessageLayout layout;
  final List<MessageEntity> cardMessages;
  final bool isCardHeader;
  final bool isCardTail;
  final SentinelEntity sentinel;

  const _AssistantMessageItem({
    required this.layout,
    required this.cardMessages,
    required this.isCardHeader,
    required this.isCardTail,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    final message = layout.message;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        isCardHeader ? 12 : 0,
        16,
        isCardTail ? 16 : 0,
      ),
      child: _AssistantMessageSegment(
        key: ValueKey(
          'assistant-card-segment-${message.id ?? identityHashCode(message)}',
        ),
        layout: layout,
        isCardHeader: isCardHeader,
        cardMessages: cardMessages,
        sentinel: sentinel,
      ),
    );
  }
}

/// 卡内一条消息的呈现。
///
/// 因为整张卡是一个列表项，卡内消息数可能很大，而流式期间每来一个 delta 都会
/// 重建整张卡。这里按"渲染输入清单"记忆化：清单未变时返回同一个 Widget 实例，
/// Flutter 的 `updateChild` 会直接跳过这棵子树，于是增量只重建真正变化的那条
/// 消息，长卡的每次 delta 开销仍接近常数。
///
/// 清单用值比较而非哈希，避免碰撞造成画面陈旧；漏判只会导致多重建一次，
/// 不会渲染错内容。
class _AssistantMessageSegment extends StatelessWidget {
  final AssistantMessageLayout layout;
  final bool isCardHeader;
  final List<MessageEntity> cardMessages;
  final SentinelEntity sentinel;

  const _AssistantMessageSegment({
    super.key,
    required this.layout,
    required this.isCardHeader,
    required this.cardMessages,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCardHeader
            ? _buildAssistantAvatar(context, sentinel)
            : const SizedBox(width: 36),
        const SizedBox(width: 12),
        Expanded(child: _AssistantMessageContent(layout: layout)),
        _buildAssistantTrailingSpace(),
      ],
    );
    final showCopyButton = isCardHeader && !layout.waitingForFirstDelta;
    Widget result = showCopyButton
        ? Stack(
            children: [
              row,
              Positioned(
                right: 0,
                child: CopyButton(
                  color: colors.textPrimary,
                  onTap: () => _copyAssistantMessages(cardMessages),
                ),
              ),
            ],
          )
        : row;
    if (layout.addBoundarySpacing) {
      result = Padding(padding: const EdgeInsets.only(top: 12), child: result);
    }
    return result;
  }
}

class _AssistantMessageContent extends StatelessWidget {
  final AssistantMessageLayout layout;

  const _AssistantMessageContent({required this.layout});

  @override
  Widget build(BuildContext context) {
    final message = layout.message;
    if (message.role == 'compaction') {
      final step = CompactionStep.fromMessage(message);
      return CompactionCard(
        key: ValueKey(step.compactionId),
        step: step,
        isLive: layout.isLive,
      );
    }
    final children = <Widget>[];
    if (layout.waitingForFirstDelta) {
      children.add(const _AssistantMessageWaitingPart());
    }
    for (final (index, part) in layout.parts.indexed) {
      switch (part) {
        case StepsPart():
          children.add(_buildStepsPart(message, part, index));
        case ContentPart():
          children.add(const SizedBox(height: 8));
          children.add(AthenaMarkdown(message: message));
        case ReferencePart():
          children.add(
            _AssistantMessageListTileReferencePart(message: message),
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 步骤数 ≥ 2 收纳为折叠的步骤组；单步保持平铺（推理卡 / 单工具卡）。
  Widget _buildStepsPart(MessageEntity host, StepsPart part, int index) {
    final steps = part.steps;
    if (steps.length == 1) {
      return switch (steps.single) {
        ReasoningStep(:final message) => ReasoningCard(
          key: ValueKey('reasoning-${_identityOf(message)}'),
          message: message,
          thinking: part.live,
        ),
        ToolCallStep step => ToolCard(
          key: ValueKey('tool-${step.id}'),
          toolName: step.toolName,
          arguments: step.arguments,
          result: step.result,
        ),
      };
    }
    return StepGroupCard(
      key: ValueKey('steps-${_identityOf(host)}-$index'),
      steps: steps,
      live: part.live,
    );
  }

  static Object _identityOf(MessageEntity message) =>
      message.id ?? identityHashCode(message);
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

class _AssistantMessageWaitingPart extends StatelessWidget {
  const _AssistantMessageWaitingPart();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 卡面即页面底色，用页面族文字色
    final foreground = colors.textSecondary;
    return ToolHeaderShimmer(
      active: true,
      child: Row(
        children: [
          Icon(HugeIcons.strokeRoundedSparkles, size: 15, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Working…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.firaCode(fontSize: 12, color: foreground),
            ),
          ),
        ],
      ),
    );
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
        color: colors.codeBackground,
      );
      var textStyle = GoogleFonts.firaCode(
        fontWeight: FontWeight.w500,
        color: colors.textOnCode,
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
      color: colors.textOnCode,
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
    // 不绘制底板：重试按钮只保留图标本身
    var container = Container(
      padding: const EdgeInsets.all(6),
      child: Icon(
        HugeIcons.strokeRoundedRefresh,
        size: 12,
        color: colors.iconSecondary,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResend,
      child: container,
    );
  }
}
