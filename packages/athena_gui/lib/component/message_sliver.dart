import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter/material.dart';

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

  /// 这张助手卡属于**尚未结束的那一轮**：操作条不显形。只有助手卡会为 true，
  /// 用户消息不受影响。
  final bool suppressActions;

  const _MessageListRenderItem({
    required this.message,
    this.layout,
    this.cardMessages = const [],
    this.isCardHeader = false,
    this.isCardTail = false,
    required this.addCardSpacing,
    this.suppressActions = false,
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
/// 该约束一并消失。
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
            child = AssistantMessageItem(
              layout: layout,
              cardMessages: item.cardMessages,
              isCardHeader: item.isCardHeader,
              isCardTail: item.isCardTail,
              sentinel: widget.sentinel,
              hover: hover,
              suppressActions: item.suppressActions,
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
            // 轮次之间留 16
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
  // 流式中先算出「正在进行的这一轮」的起点：最后一条用户消息。只有**这张轮次里的
  // 助手卡**受它影响（操作条不显形），用户消息照常 hover 显形。卡片不会跨用户消息
  // （助手卡的成员只可能是 assistant / compaction），所以一张卡要么整张在内、
  // 要么整张在外。
  final activeTurnStart = loading
      ? _activeTurnStartIndex(messages)
      : messages.length;
  var messageIndex = 0;

  for (final (cardIndex, cardMessages) in cards.indexed) {
    final cardStart = messageIndex;
    messageIndex += cardMessages.length;
    final message = cardMessages.first;
    if (!isAssistantCardMessage(message)) {
      result.add(
        _MessageListRenderItem(message: message, addCardSpacing: cardIndex > 0),
      );
      continue;
    }

    final suppressActions = cardStart + cardMessages.length > activeTurnStart;

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
          suppressActions: suppressActions,
        ),
      );
    }
  }

  return result;
}

/// 正在进行的这一轮的起始消息下标：**最后一条用户消息**。
///
/// 一轮 = 一条用户消息 + 它之后的所有助手消息，所以从这条用户消息起、含它在内
/// 的助手卡都算"还没结束"（这条用户消息本身不算，它的操作条照常 hover 显形）。
/// 列表里没有用户消息时（历史被压缩、只剩助手消息等）退化成只剩最后一条，
/// 宁可少藏也不要整列都藏。
int _activeTurnStartIndex(List<MessageEntity> messages) {
  for (var index = messages.length - 1; index >= 0; index--) {
    if (messages[index].role == 'user') return index;
  }
  return messages.length - 1;
}
