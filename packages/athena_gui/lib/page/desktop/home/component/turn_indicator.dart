import 'dart:async';

import 'package:athena_gui/page/desktop/home/component/chat_preview_card.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/chat_turn_util.dart';
import 'package:flutter/material.dart';

/// 工作区左侧的轮次指示器：**一条 = 一轮**，深色那条是视口当前所在的一轮。
///
/// 条长不是固定的：鼠标停在哪条哪条最长，其余按与它的**距离**递减（相邻的
/// 自然比远处的长），没有 hover 时全部等长。宽度上限由调用方按工作区留白给出
/// ——窄窗口里定宽列的留白被压缩，条跟着变短，不会压到正文上。
///
/// 交互：hover 弹预览卡（第一行 = 该轮用户消息，第二行 = 该轮 agent 回答），
/// 点击把那一轮滚到视口顶部（滚动由 [TurnNavigator] 落到消息 sliver 上）。
/// 它只占条本身那一小条命中区，其余地方指针直接穿过去，不影响读消息。
class TurnIndicator extends StatefulWidget {
  /// 与消息列表顺序一致的轮次（通常只是已加载的窗口）。
  final List<ChatTurn> turns;
  final TurnNavigator navigator;

  /// 单条最大宽度；静止时取它的一半。
  final double maxBarWidth;

  const TurnIndicator({
    super.key,
    required this.turns,
    required this.navigator,
    required this.maxBarWidth,
  });

  /// 静止长度 = 最大宽度 × 该比例。
  static const double restingWidthFactor = 0.5;

  /// 距离衰减跨度：与 hover 那条相隔这么多条及以上就回到静止长度。
  static const int falloffSpread = 4;

  static const double barHeight = 4;

  /// 单条命中行高（条居中，上下各留一点，条才点得中）。
  static const double barRowHeight = 12;

  /// 条长与颜色的过渡时长，跟全站 hover 过渡一致。
  static const Duration barDuration = Duration(milliseconds: 120);

  /// hover 多久弹预览卡。比侧栏会话行的 400ms 短：条是小目标，停在上面
  /// 本身就是明确的意图。
  static const Duration previewDelay = Duration(milliseconds: 150);

  @override
  State<TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<TurnIndicator> {
  int? _hoveredIndex;
  Timer? _previewTimer;
  final Map<int, GlobalKey> _barKeys = {};

  @override
  void didUpdateWidget(covariant TurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切会话 / 轮次变化后卡片可能指向已经不存在的一轮
    if (oldWidget.turns.length != widget.turns.length ||
        !identical(oldWidget.turns, widget.turns)) {
      _previewTimer?.cancel();
      DesktopChatPreviewManager.instance.dismissFor(this);
      if (_hoveredIndex != null && _hoveredIndex! >= widget.turns.length) {
        _hoveredIndex = null;
      }
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    super.dispose();
  }

  GlobalKey _barKey(int index) => _barKeys.putIfAbsent(
    index,
    () => GlobalKey(debugLabel: 'turn-bar-$index'),
  );

  /// 条长：hover 那条最长，其余按距离线性递减到静止长度。
  double _barWidth(int index) {
    final resting = widget.maxBarWidth * TurnIndicator.restingWidthFactor;
    final hovered = _hoveredIndex;
    if (hovered == null) return resting;
    final distance = (index - hovered).abs();
    if (distance >= TurnIndicator.falloffSpread) return resting;
    final weight = 1 - distance / TurnIndicator.falloffSpread;
    return resting + (widget.maxBarWidth - resting) * weight;
  }

  void _handleEnter(int index) {
    setState(() => _hoveredIndex = index);
    _previewTimer?.cancel();
    _previewTimer = Timer(
      TurnIndicator.previewDelay,
      () => _showPreview(index),
    );
  }

  void _handleExit(int index) {
    if (_hoveredIndex == index) setState(() => _hoveredIndex = null);
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
  }

  void _handleTap(int index) {
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    widget.navigator.scrollToTurn(index);
  }

  void _showPreview(int index) {
    if (!mounted || _hoveredIndex != index || index >= widget.turns.length) {
      return;
    }
    final box = _barKey(index).currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final barRect = box.localToGlobal(Offset.zero) & box.size;
    final turn = widget.turns[index];
    DesktopChatPreviewManager.instance.show(
      context,
      owner: this,
      // 横向锚点取「最大条宽」而不是这条的当前宽度：条的宽度正随 hover
      // 动画生长，卡片跟着长会让它抖，位置也因哪条被 hover 而变
      anchor: Rect.fromLTRB(
        barRect.left,
        barRect.top,
        barRect.left + widget.maxBarWidth,
        barRect.bottom,
      ),
      title: turn.user.content,
      answer: turn.answer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.navigator.currentTurnIndex,
      builder: (context, currentIndex, _) {
        final colors = Theme.of(context).extension<AthenaColors>()!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < widget.turns.length; index++)
              _buildBar(colors, index, currentIndex),
          ],
        );
      },
    );
  }

  Widget _buildBar(AthenaColors colors, int index, int currentIndex) {
    // 视口当前那一轮与 hover 那一轮都用行标签色，其余用次级图标色压到 45%——
    // 与侧栏会话行状态点的静止档同一套灰阶。
    final highlighted = index == _hoveredIndex || index == currentIndex;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleEnter(index),
      onExit: (_) => _handleExit(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(index),
        child: SizedBox(
          height: TurnIndicator.barRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              key: _barKey(index),
              duration: TurnIndicator.barDuration,
              curve: Curves.easeOut,
              width: _barWidth(index),
              height: TurnIndicator.barHeight,
              decoration: BoxDecoration(
                color: highlighted
                    ? colors.textRowLabel
                    : colors.iconSecondary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AthenaRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
