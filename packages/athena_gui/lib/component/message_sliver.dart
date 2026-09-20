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
