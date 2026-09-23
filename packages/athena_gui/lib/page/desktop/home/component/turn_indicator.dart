import 'dart:async';
import 'dart:math' as math;

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
/// **整列最多画 [maxBars] 条**：一条 = 一条 user message，但只画**视口当前轮
/// 所在的那一页**（每 [maxBars] 轮一页）。轮次多的会话不再把整列拉长，也不必
/// 把行高压矮——压矮会让条密到点不中，等于把这一列废掉。页内的条保持正常大小
/// 与间距，且页内摆位稳定（页内跳转不重排）；跨页（滚动、或跳转把当前轮带过
/// 页边界）时整列按新的当前轮重建。要看更早/更晚的轮次就滚到那一页——视口当前
/// 轮由消息 sliver 上报，窗口自己会跟过来。
///
/// 页内的条分两种：已加载那几轮（内容在手，可 hover 弹预览卡）与更早的历史
/// （照样按同一套长度与颜色画、照样能当 hover 锚点、照样能点，只是没有内容可
/// 预览，点它由宿主先去补历史）。两者用的是同一套公式（[barWidthFor] /
/// [barColorFor]），没有"未加载就更短 / 更淡"的专用档位。
///
/// 交互：hover 弹预览卡（第一行 = 该轮用户消息，第二行 = 该轮 agent 回答），
/// 点击把那一轮滚到视口顶部（滚动由 [TurnNavigator] 落到消息 sliver 上）。
/// 它只占条本身那一小条命中区，其余地方指针直接穿过去，不影响读消息。
class TurnIndicator extends StatefulWidget {
  /// 已加载窗口里的轮次，与消息列表顺序一致；只有这些有内容可预览。
  final List<ChatTurn> turns;
  final TurnNavigator navigator;

  /// 单条最大宽度；静止时取它的一半。
  final double maxBarWidth;

  /// 整段会话的轮数 = user 消息数（含尚未加载的历史）。
  ///
  /// 消息列表是窗口化分页的，[turns] 只是尾部一段；条数按整段会话算，而且
  /// **不从 [turns] 推**——那是窗口，计数是整段会话的属性（见
  /// `ChatViewModel.turnStartIds`）。整列按它切页（见 [maxBars]）。
  final int totalTurns;

  /// [turns] 第一轮在整段会话里的下标，用来把窗口内的条摆到正确位置。
  final int firstTurnIndex;

  /// 某一条被点中，参数是它在**整段会话**里的下标（不是窗口内下标）。
  ///
  /// 落到哪一轮、要不要先把历史翻页补进来，由宿主决定（见
  /// `_DesktopMessageListState._selectTurn`）。
  final void Function(int absoluteTurnIndex) onTurnSelected;

  const TurnIndicator({
    super.key,
    required this.turns,
    required this.navigator,
    required this.maxBarWidth,
    required this.totalTurns,
    required this.firstTurnIndex,
    required this.onTurnSelected,
  });

  /// 静止长度 = 最大宽度 × 该比例。
  static const double restingWidthFactor = 0.5;

  /// 静止档的条色：次级图标色压到该不透明度——与侧栏会话行状态点的静止档
  /// 同一套灰阶。
  static const double restingBarAlpha = 0.45;

  /// 距离衰减跨度：与 hover 那条相隔这么多条及以上就回到静止长度。
  static const int falloffSpread = 4;

  static const double barHeight = 4;

  /// 单条命中行高（条居中，上下各留一点，条才点得中）。
  static const double barRowHeight = 12;

  /// 整列最多画几条 = 一页多少轮。超过就分页，只画视口当前轮所在的那一页。
  ///
  /// 20 条按 [barRowHeight] 排是 240 高，落在消息区里不占地方又点得中；这是
  /// "一页多大"的唯一旋钮。
  static const int maxBars = 20;

  /// 条长与颜色的过渡时长，跟全站 hover 过渡一致。
  static const Duration barDuration = Duration(milliseconds: 120);

  /// hover 多久弹预览卡。比侧栏会话行的 400ms 短：条是小目标，停在上面
  /// 本身就是明确的意图。
  static const Duration previewDelay = Duration(milliseconds: 150);

  /// 条长的**唯一**公式：静止 = 上限 × [restingWidthFactor]；有 hover 时那一条
  /// 最长（= 上限），其余按与它的距离线性递减，相隔 [falloffSpread] 条及以上
  /// 回到静止长度。
  ///
  /// [index] 与 [hoveredIndex] 都是**整段会话**里的下标：距离要跨"已加载 /
  /// 未加载"那条线算，否则 hover 页内历史那一条时，紧挨着它的已加载条不会跟着
  /// 变长。
  static double barWidthFor({
    required int index,
    required int? hoveredIndex,
    required double maxBarWidth,
  }) {
    final resting = maxBarWidth * restingWidthFactor;
    if (hoveredIndex == null) return resting;
    final distance = (index - hoveredIndex).abs();
    if (distance >= falloffSpread) return resting;
    final weight = 1 - distance / falloffSpread;
    return resting + (maxBarWidth - resting) * weight;
  }

  /// 条色的**唯一**公式：hover 那条与视口当前那条用行标签色，其余是静止档。
  static Color barColorFor({
    required bool highlighted,
    required AthenaColors colors,
  }) => highlighted
      ? colors.textRowLabel
      : colors.iconSecondary.withValues(alpha: restingBarAlpha);

  @override
  State<TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<TurnIndicator> {
  /// hover 锚点，整段会话的下标；页内任何一条都能当锚点。
  int? _hoveredIndex;

  Timer? _previewTimer;
  final Map<int, GlobalKey> _barKeys = {};

  /// 整段会话画多少行 = 窗口那几轮 + 未加载的历史。窗口首轮的下标大于扫描到的
  /// 总轮数时以窗口为准——新发出的消息先落进窗口、扫描还没跟上时会这样。
  int get _rowCount =>
      math.max(widget.totalTurns, widget.firstTurnIndex + widget.turns.length);

  /// 已加载窗口在整段会话里的下标区间（左闭右开）。
  int get _windowStart => widget.firstTurnIndex;
  int get _windowEnd => widget.firstTurnIndex + widget.turns.length;

  bool _isLoaded(int absoluteIndex) =>
      absoluteIndex >= _windowStart && absoluteIndex < _windowEnd;

  /// 视口当前轮，**整段会话**的下标（[TurnNavigator.currentTurnIndex] 报的是
  /// 窗口内的下标，要加上窗口首轮的位置；-1 = 还没测出来、或本次没有轮次）。
  int get _absoluteCurrentTurn {
    final windowIndex = widget.navigator.currentTurnIndex.value;
    return windowIndex < 0 ? -1 : widget.firstTurnIndex + windowIndex;
  }

  /// 整列当前画的那一页的起点（整段会话下标）。
  ///
  /// 当前轮还没上报时（打开会话的首帧）按"停在最新"算：打开时视口就在列表
  /// 底部，这样首帧画的就是最后一页，不会先闪一页再跳过去。
  int get _pageStart {
    final rows = _rowCount;
    if (rows <= TurnIndicator.maxBars) return 0;
    final current = _absoluteCurrentTurn;
    final anchor = current < 0 || current >= rows ? rows - 1 : current;
    return (anchor ~/ TurnIndicator.maxBars) * TurnIndicator.maxBars;
  }

  @override
  void initState() {
    super.initState();
    widget.navigator.currentTurnIndex.addListener(_handleCurrentTurnChanged);
  }

  @override
  void didUpdateWidget(covariant TurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.navigator, widget.navigator)) {
      oldWidget.navigator.currentTurnIndex.removeListener(
        _handleCurrentTurnChanged,
      );
      widget.navigator.currentTurnIndex.addListener(_handleCurrentTurnChanged);
    }
    final windowChanged =
        oldWidget.totalTurns != widget.totalTurns ||
        oldWidget.firstTurnIndex != widget.firstTurnIndex ||
        oldWidget.turns.length != widget.turns.length ||
        !identical(oldWidget.turns, widget.turns);
    if (!windowChanged) return;
    // 切会话 / 翻页 / 轮次变化：卡片可能指向已经不存在的一轮，hover 也可能落在
    // 已经不存在的那一行上
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    if (_hoveredIndex != null && _hoveredIndex! >= _rowCount) {
      _hoveredIndex = null;
    }
    _barKeys.clear();
  }

  @override
  void dispose() {
    widget.navigator.currentTurnIndex.removeListener(_handleCurrentTurnChanged);
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    super.dispose();
  }

  /// 视口当前轮变了：高亮那条要换色、当前轮跨过页边界时整列还要换页——都在
  /// 这一次重建里（值由 getter 现取，不必先存一份）。
  void _handleCurrentTurnChanged() {
    if (mounted) setState(() {});
  }

  GlobalKey _barKey(int absoluteIndex) => _barKeys.putIfAbsent(
    absoluteIndex,
    () => GlobalKey(debugLabel: 'turn-bar-$absoluteIndex'),
  );

  /// 指针停在某一轮上（页内已加载的条与未加载的历史条都调到这里）。
  void _setHovered(int? absoluteIndex) {
    if (_hoveredIndex == absoluteIndex) return;
    _previewTimer?.cancel();
    if (absoluteIndex != null && _isLoaded(absoluteIndex)) {
      _previewTimer = Timer(
        TurnIndicator.previewDelay,
        () => _showPreview(absoluteIndex),
      );
    } else {
      // 未加载的历史没有内容可预览：照样变长，但不弹卡
      DesktopChatPreviewManager.instance.dismissFor(this);
    }
    setState(() => _hoveredIndex = absoluteIndex);
  }

  void _handleExit(int absoluteIndex) {
    if (_hoveredIndex == absoluteIndex) _setHovered(null);
  }

  void _handleTap(int absoluteIndex) {
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    // 报整段会话的下标：宿主据此决定是直接滚，还是先翻页把这一轮补进来
    widget.onTurnSelected(absoluteIndex);
  }

  void _showPreview(int absoluteIndex) {
    if (!mounted ||
        _hoveredIndex != absoluteIndex ||
        !_isLoaded(absoluteIndex)) {
      return;
    }
    final box =
        _barKey(absoluteIndex).currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final barRect = box.localToGlobal(Offset.zero) & box.size;
    final turn = widget.turns[absoluteIndex - _windowStart];
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _rowCount;
        final pageStart = _pageStart;
        final pageEnd = math.min(pageStart + TurnIndicator.maxBars, rows);
        final pageRows = math.max(0, pageEnd - pageStart);
        // 一页最多 20 条，正常情况用满行高；窗口矮到放不下这一页时才压（那时
        // 整列本来也铺不下）。旧版按**整段会话**的轮数压行高，几十轮就压得点不中
        final rowHeight = pageRows <= 0 || !constraints.hasBoundedHeight
            ? TurnIndicator.barRowHeight
            : math.min(
                TurnIndicator.barRowHeight,
                constraints.maxHeight / pageRows,
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = pageStart; index < pageEnd; index++)
              _buildBar(colors, index, rowHeight),
          ],
        );
      },
    );
  }

  Widget _buildBar(AthenaColors colors, int absoluteIndex, double rowHeight) {
    // 视口当前那一轮与 hover 那一轮都用行标签色，其余次级图标色压到 45%——
    // 与侧栏会话行状态点的静止档同一套灰阶。
    final highlighted =
        absoluteIndex == _hoveredIndex || absoluteIndex == _absoluteCurrentTurn;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(absoluteIndex),
      onExit: (_) => _handleExit(absoluteIndex),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(absoluteIndex),
        child: SizedBox(
          height: rowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              key: _barKey(absoluteIndex),
              duration: TurnIndicator.barDuration,
              curve: Curves.easeOut,
              width: TurnIndicator.barWidthFor(
                index: absoluteIndex,
                hoveredIndex: _hoveredIndex,
                maxBarWidth: widget.maxBarWidth,
              ),
              // 行变矮时条也跟着变薄，密到极限时仍留一条可见的线
              height: math.min(TurnIndicator.barHeight, rowHeight * 0.6),
              decoration: BoxDecoration(
                color: TurnIndicator.barColorFor(
                  highlighted: highlighted,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(AthenaRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
