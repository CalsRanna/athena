import 'dart:convert';


import 'package:athena_gui/component/compaction_card.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/base64_image.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/component/reasoning_card.dart';
import 'package:athena_gui/component/step_group_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class MessageCardListSliver extends StatefulWidget {
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
  State<MessageCardListSliver> createState() => _MessageCardListSliverState();
}

class _MessageCardListSliverState extends State<MessageCardListSliver> {
  final hover = AssistantCardHover();

  @override
  void dispose() {
    hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderItems = _buildMessageListRenderItems(
      widget.messages,
      loading: widget.loading,
    );
    final itemIndices = <String, int>{
      for (final (index, item) in renderItems.indexed) item.key: index,
    };
    return SliverPadding(
      padding: widget.padding,
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
              sentinel: widget.sentinel,
              hover: hover,
            );
          } else {
            child = MessageListTile(
              message: item.message,
              loading:
                  widget.loading && item.message.id == widget.messages.last.id,
              onLongPress: widget.onLongPress == null
                  ? null
                  : () => widget.onLongPress!(item.message),
              onSecondaryTapUp: widget.onSecondaryTapUp == null
                  ? null
                  : (details) =>
                        widget.onSecondaryTapUp!(details, item.message),
              onResend: widget.onResend == null
                  ? null
                  : () => widget.onResend!(item.message),
              sentinel: widget.sentinel,
            );
          }
          if (item.addCardSpacing) {
            // Codex 的轮次容器是 gap-4，即 16
            child = Padding(
              padding: const EdgeInsets.only(top: 16),
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

class _AssistantMessageListTile extends StatefulWidget {
  final bool loading;
  final MessageEntity message;
  final SentinelEntity sentinel;

  const _AssistantMessageListTile({
    this.loading = false,
    required this.message,
    required this.sentinel,
  });

  @override
  State<_AssistantMessageListTile> createState() =>
      _AssistantMessageListTileState();
}

class _AssistantMessageListTileState extends State<_AssistantMessageListTile> {
  final hover = AssistantCardHover();

  @override
  void dispose() {
    hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layouts = buildAssistantMessageLayouts(
      [widget.message],
      loading: widget.loading,
    );
    if (layouts.isEmpty) return const SizedBox.shrink();
    return _AssistantMessageItem(
      layout: layouts.first,
      cardMessages: [widget.message],
      isCardHeader: true,
      isCardTail: true,
      sentinel: widget.sentinel,
      hover: hover,
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

  /// 卡片级 hover 归属：操作条挂在整条助手消息上，而不是某一段上。
  final AssistantCardHover hover;

  const _AssistantMessageItem({
    required this.layout,
    required this.cardMessages,
    required this.isCardHeader,
    required this.isCardTail,
    required this.sentinel,
    required this.hover,
  });

  @override
  Widget build(BuildContext context) {
    final message = layout.message;
    return Padding(
      // 列内左右留白：Claude 的助手正文用 `--cds-assistant-message-text-inset`
      // (4) 贴住 768 定宽列的左缘，右侧留 `--cds-assistant-message-text-stop`
      // （宽列下最多 56）给换行收窄。旧版左 12 + 列表内边距 16 共 28，比
      // Claude 右移了一整档，正文因此显得没有对齐 composer。
      padding: EdgeInsets.fromLTRB(
        4,
        isCardHeader ? 16 : 0,
        32,
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
        hover: hover,
        cardId: cardMessages.first.id ?? identityHashCode(cardMessages.first),
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
  final AssistantCardHover hover;

  /// 本段所属助手卡的标识，用来判定"指针是否在这张卡上"。
  final Object cardId;

  const _AssistantMessageSegment({
    super.key,
    required this.layout,
    required this.isCardHeader,
    required this.cardMessages,
    required this.sentinel,
    required this.hover,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    // 助手消息没有头像、没有气泡：内容直接铺满列宽。
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _AssistantMessageContent(layout: layout)),
        // 右侧余量对应 Claude 的 `--cds-assistant-message-text-stop`：
        // 让正文换行收窄，同时给 hover 工具条留出不压字的落脚点。
        const SizedBox(width: 24),
      ],
    );
    final showActions = isCardHeader && !layout.waitingForFirstDelta;
    // Claude 的操作条属于**整条消息行**（`.group\/message-row:hover
    // [data-cds=MessageActions]`）：指针落在卡内任意一段都要显形。本仓每段
    // 消息各占一个列表项，所以 hover 状态放在卡片级的 [AssistantCardHover]
    // 上，这里只负责上报进出、并按共享状态决定操作条是否可见。
    // 只有操作条订阅该 notifier，正文不参与重建。
    Widget result = MouseRegion(
      onEnter: (_) => hover.enter(cardId),
      onExit: (_) => hover.leave(cardId),
      child: showActions
          ? Stack(
              children: [
                row,
                Positioned(
                  right: 0,
                  child: ValueListenableBuilder<Object?>(
                    valueListenable: hover.hoveredCard,
                    builder: (context, hoveredCard, _) => _MessageActionBar(
                      visible: hoveredCard == cardId,
                      onCopy: () => _copyAssistantMessages(cardMessages),
                    ),
                  ),
                ),
              ],
            )
          : row,
    );
    if (layout.addBoundarySpacing) {
      result = Padding(padding: const EdgeInsets.only(top: 16), child: result);
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
              style: TextStyle(
                fontSize: AthenaFontSize.label,
                color: foreground,
              ),
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
      var textStyle = TextStyle(
        fontWeight: FontWeight.w600,
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
      style: TextStyle(color: colors.markdownLink),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 工具消息没有工具名可用（MessageEntity 无 tool_call_id），
    // 内容以浅灰代码块样式呈现，与 ToolCard 展开区呼应。
    var textStyle = athenaMono(
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // Codex 的用户消息：**右对齐的浅灰气泡**，取自它的类
    // `bg-text/5 max-w-[77%] rounded-2xl px-3 py-2`，容器 `items-end justify-end`。
    // 没有头像。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.77,
                ),
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: _buildContent(context),
              ),
            ),
            const SizedBox(width: 4),
            _buildResendButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 用户消息为正文级别，用主题化正文色（浅色模式下近黑）。
    // 字号 / 行高与助手正文同一档（prose 15 / 22），否则一轮对话里
    // 问与答的字号会不一致。
    var textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaFontSize.prose,
      height: AthenaFontSize.proseHeight,
    );
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
    return gestureDetector;
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

/// 助手卡的 hover 归属。
///
/// Claude 的消息操作条挂在**整条消息行**上（`.group\/message-row:hover`
/// 时 `[data-cds=MessageActions]` 显形），指针落在卡内任意一段都算 hover。
/// 本仓每段消息各占一个独立列表项、各自持有 MouseRegion，因此用一个卡级的
/// 共享 notifier 把各段的上报汇总起来：任意段进入即记为该卡，离开即清空。
///
/// 只有操作条订阅它，正文不参与重建，流式追加时的重建成本不变。
class AssistantCardHover {
  /// 当前被 hover 的卡片标识；`null` 表示没有任何卡片被 hover。
  final ValueNotifier<Object?> hoveredCard = ValueNotifier<Object?>(null);

  void enter(Object cardId) {
    if (hoveredCard.value != cardId) hoveredCard.value = cardId;
  }

  void leave(Object cardId) {
    if (hoveredCard.value == cardId) hoveredCard.value = null;
  }

  void dispose() => hoveredCard.dispose();
}

/// hover 才显形的消息操作条。
///
/// 逐条对齐 Claude 的 `[data-cds=MessageActions][data-reveal]`：
/// - **只动透明度**——`--cds-message-actions-reveal-scale` 在 `.cds-root`
///   上是 `none`，旧版加的 `scale(0.9)` 是自创的；
/// - 进入用 `--cds-dur-snap`(120ms) **且延迟** `...-reveal-in-delay`(100ms)；
/// - 退出用 `--cds-dur-fast`(60ms) 且无延迟。
/// 延迟用 `Interval` 曲线表达：前 100/220 的进度里保持全透明。
class _MessageActionBar extends StatelessWidget {
  final bool visible;
  final VoidCallback? onCopy;

  const _MessageActionBar({required this.visible, this.onCopy});

  static const _inDelayMs = 100.0;
  static const _inDurMs = 120.0;
  static const _outDurMs = 60.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(
          milliseconds: (visible ? _inDelayMs + _inDurMs : _outDurMs).round(),
        ),
        curve: visible
            ? const Interval(
                _inDelayMs / (_inDelayMs + _inDurMs),
                1,
                curve: Curves.easeOut,
              )
            : Curves.linear,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MessageActionButton(
              icon: HugeIcons.strokeRoundedCopy01,
              tooltip: 'Copy',
              onTap: onCopy,
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作条上的一个 ghost 图标按钮。
///
/// 尺寸取自 Claude：控件高 `--cds-h-control`(24)，图标 `--cds-icon`(16)，
/// 圆角 `--cds-radius--lg`(7)，hover 填充 `--cds-fill-ghost-hover`
/// （浅色 alpha-1 ≈ 5%）。
class _MessageActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _MessageActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  State<_MessageActionButton> createState() => _MessageActionButtonState();
}

class _MessageActionButtonState extends State<_MessageActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.textPrimary.withValues(alpha: 0.05)
                  : colors.textPrimary.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(AthenaRadius.row),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: colors.iconSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
