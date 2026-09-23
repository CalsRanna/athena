import 'dart:math' as math;

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/util/sliver_item_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  /// 轮次导航桥（可选）：登记后由本 sliver 上报「视口当前在第几轮」，
  /// 并接受「跳到第几轮」的请求。
  final TurnNavigator? navigator;

  const MessageCardListSliver({
    super.key,
    this.loading = false,
    required this.messages,
    required this.sentinel,
    this.padding = EdgeInsets.zero,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.onResend,
    this.navigator,
  });

  @override
  State<MessageCardListSliver> createState() => _MessageCardListSliverState();
}

class _MessageCardListSliverState extends State<MessageCardListSliver> {
  /// 跳转时最多粗跳几次。懒加载列表里目标项可能还没被构建，只能按索引差
  /// 估一屏再量一次；实测（几十项以内的跨度）两三次就到位。
  static const int _maxScrollAttempts = 8;

  /// 粗跳时单次最多走几屏：估得太远会来回震荡。
  static const double _maxJumpViewports = 2.5;

  static const Duration _jumpDuration = Duration(milliseconds: 240);

  final hover = AssistantCardHover();

  /// 挂在 [SliverList] 上，用来在布局之后读子项的实际位置。
  final _sliverKey = GlobalKey();

  ScrollPosition? _position;

  /// 每一轮起点（用户消息）对应的列表项下标，与消息顺序一致。
  List<int> _turnStarts = const [];
  bool _reportScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.navigator?.bindScroller(_scrollToTurn);
  }

  @override
  void didUpdateWidget(covariant MessageCardListSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.navigator, widget.navigator)) {
      oldWidget.navigator?.bindScroller(null);
      widget.navigator?.bindScroller(_scrollToTurn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = _scrollPosition();
    if (identical(position, _position)) return;
    _position?.removeListener(_scheduleTurnReport);
    _position = position;
    _position?.addListener(_scheduleTurnReport);
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleTurnReport);
    widget.navigator?.bindScroller(null);
    hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderItems = _buildMessageListRenderItems(
      widget.messages,
      loading: widget.loading,
    );
    _turnStarts = [
      for (final (index, item) in renderItems.indexed)
        if (item.layout == null && item.message.role == 'user') index,
    ];
    // 内容变化后（新消息、翻页、切会话）视口落在哪一轮也会变
    _scheduleTurnReport();
    final itemIndices = <String, int>{
      for (final (index, item) in renderItems.indexed) item.key: index,
    };
    return SliverPadding(
      padding: widget.padding,
      sliver: SliverList.builder(
        key: _sliverKey,
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

  // ─── 轮次探测与跳转 ───────────────────────────────────────

  ScrollPosition? _scrollPosition() {
    // position 在 Scrollable 建好之前是不存在的；这里只在 didChangeDependencies
    // 调用，此时祖先 Scrollable 已经挂上 position。
    return Scrollable.maybeOf(context)?.position;
  }

  RenderSliverList? get _sliver {
    final object = _sliverKey.currentContext?.findRenderObject();
    return object is RenderSliverList ? object : null;
  }

  void _scheduleTurnReport() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      _reportCurrentTurn();
    });
  }

  /// 上报视口当前所在的那一轮：取视口里占得最多的那一项所属的轮次。
  void _reportCurrentTurn() {
    final navigator = widget.navigator;
    if (navigator == null || !mounted) return;
    final dominant = _dominantItemIndex();
    navigator.currentTurnIndex.value = dominant == null
        ? -1
        : _turnIndexForItem(dominant) ?? -1;
  }

  /// 视口里占得最多的那一项下标（懒加载列表里只有已构建的项能参与）。
  int? _dominantItemIndex() {
    final sliver = _sliver;
    return sliver == null ? null : SliverItemMetrics.dominantItemIndex(sliver);
  }

  /// 视口内**可见**的第一项下标。
  ///
  /// 懒加载 sliver 只构建视口（含缓存区）附近的项，所以遍历已构建的子项、
  /// 取「下边缘越过视口顶」里最靠上的那个即可（坐标系换算见
  /// [SliverItemMetrics]）。
  int? _firstVisibleItemIndex() {
    final sliver = _sliver;
    return sliver == null ? null : SliverItemMetrics.firstVisibleIndex(sliver);
  }

  int? _turnIndexForItem(int itemIndex) {
    int? turn;
    for (var index = 0; index < _turnStarts.length; index++) {
      if (_turnStarts[index] > itemIndex) break;
      turn = index;
    }
    return turn;
  }

  /// 把第 [turnIndex] 轮滚到视口顶部。
  Future<void> _scrollToTurn(int turnIndex) async {
    final position = _position;
    if (position == null || turnIndex < 0 || turnIndex >= _turnStarts.length) {
      return;
    }
    final targetItem = _turnStarts[turnIndex];
    for (var attempt = 0; attempt < _maxScrollAttempts; attempt++) {
      final offset = _viewportOffsetOfItem(targetItem);
      if (offset != null) {
        await position.animateTo(
          offset.clamp(0.0, position.maxScrollExtent),
          duration: _jumpDuration,
          curve: Curves.easeOut,
        );
        return;
      }
      // 目标项还没被构建：按索引差粗跳一段，下一帧再量。方向取自视口首边
      // 可见的那一项（目标在它上方就是负数，往上跳）。
      final firstVisible = _firstVisibleItemIndex();
      if (firstVisible == null) return;
      final step = _estimateStep(targetItem - firstVisible);
      final next = (position.pixels + step).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      position.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// 把第 [itemIndex] 项移到视口顶所需的滚动偏移；该项未被构建时返回 null。
  double? _viewportOffsetOfItem(int itemIndex) {
    final sliver = _sliver;
    final position = _position;
    if (sliver == null || position == null) return null;
    return SliverItemMetrics.viewportOffsetOf(sliver, position, itemIndex);
  }

  /// 粗跳步长：用可见项的平均高度估算，上限 [(_maxJumpViewports)] 屏。
  double _estimateStep(int deltaItems) {
    final sliver = _sliver;
    if (sliver == null || deltaItems == 0) return 0;
    final average = SliverItemMetrics.averageChildExtent(sliver);
    if (average <= 0) return 0;
    final distance = deltaItems.abs() * average;
    final cap = sliver.constraints.viewportMainAxisExtent * _maxJumpViewports;
    return deltaItems > 0
        ? math.min(distance, cap)
        : -math.min(distance, cap);
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
