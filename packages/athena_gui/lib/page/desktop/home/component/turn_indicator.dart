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
/// **一条 = 一条 user message**，整段会话都画（见 [totalTurns]），而不是只画
/// 已加载窗口里那几轮。窗口里那一段可 hover 可点（内容在手，能弹预览卡）；
/// 更早的历史照样一条条画，**长度与颜色走的是同一套公式**（[barWidthFor] /
/// [barColorFor]），没有"未加载就更短 / 更淡"这样的额外档位——两者唯一的区别
/// 是历史那几轮没有内容可预览：hover 上去照样变长、也照样带动邻居，只是不弹
/// 卡，点它由宿主先去补历史。整列因此永远是"整段会话"的比例，而不是"已加载
/// 了几轮"的比例。
///
/// 渲染分成两条路径，逻辑却只有一份（[_BarField]）：窗口里那几轮各自是控件
/// （要 hover 命中区、要弹卡、要取卡片锚点的 RenderBox），历史那几段连起来一次
/// `CustomPaint` 画完——条数可能上百上千，不为每条建控件。
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
  /// `ChatViewModel.turnStartIds`）。
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
  /// 未加载"那条线算，否则 hover 窗口边缘那一条时，紧挨着它的历史条不会跟着
  /// 变长，两段的长度场就在窗口边界上断开。
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

/// 一条轮次条在某一刻的样子：长度 + 颜色。过渡的两端都是它。
@immutable
class _BarVisual {
  final double width;
  final Color color;

  const _BarVisual(this.width, this.color);

  static _BarVisual lerp(_BarVisual from, _BarVisual to, double t) {
    if (t >= 1) return to;
    if (t <= 0) return from;
    return _BarVisual(
      from.width + (to.width - from.width) * t,
      Color.lerp(from.color, to.color, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _BarVisual && other.width == width && other.color == color;

  @override
  int get hashCode => Object.hash(width, color);
}

/// 整列的"长度 + 颜色场"。
///
/// 一条的**目标**样子只由三件事决定：它到 hover 锚点的距离
/// （[TurnIndicator.barWidthFor]）、它是不是锚点自己、它是不是视口当前轮
/// （[TurnIndicator.barColorFor]）。这套公式对窗口里的条与未加载的历史条一视
/// 同仁，没有"未加载"专用档位。
///
/// 换锚点（或视口当前轮变了）时不是逐条各存一份动画，而是整列从"此刻的样子"
/// 补间到"新的目标"：把此刻的视觉抄成起点、新目标记成目标，t 从 0 重走一遍。
/// 只有此刻已经偏离静止态的条需要抄（锚点 ± [TurnIndicator.falloffSpread] 内，
/// 十来条），其余条在整段过渡里恒为静止态——远端那些条因此仍然可以一次画完，
/// 不必参与逐条动画。
@immutable
class _BarField {
  /// 过渡起点：此后会偏离静止态的那些条。没有条目的下标 = 它此刻正是静止态。
  final Map<int, _BarVisual> origin;

  /// hover 锚点（整段会话的下标）；null = 没有 hover，整列回静止长度。
  final int? anchor;

  /// 视口当前轮（整段会话的下标）；-1 = 还没测出来。
  final int currentIndex;

  const _BarField({
    this.origin = const {},
    this.anchor,
    this.currentIndex = -1,
  });

  /// 整列的静止档视觉：没有 hover、也不是视口当前轮的样子。
  static _BarVisual restingVisual({
    required double maxBarWidth,
    required AthenaColors colors,
  }) => _BarVisual(
    maxBarWidth * TurnIndicator.restingWidthFactor,
    TurnIndicator.barColorFor(highlighted: false, colors: colors),
  );

  /// 目标视觉：过渡的终点，也是没有过渡时的样子。
  _BarVisual targetOf(
    int index, {
    required double maxBarWidth,
    required AthenaColors colors,
  }) => _BarVisual(
    TurnIndicator.barWidthFor(
      index: index,
      hoveredIndex: anchor,
      maxBarWidth: maxBarWidth,
    ),
    TurnIndicator.barColorFor(
      highlighted: index == anchor || index == currentIndex,
      colors: colors,
    ),
  );

  /// 此刻的视觉：从起点向目标补间了 [t]。
  _BarVisual visualOf(
    int index, {
    required double t,
    required double maxBarWidth,
    required AthenaColors colors,
  }) => _BarVisual.lerp(
    origin[index] ?? restingVisual(maxBarWidth: maxBarWidth, colors: colors),
    targetOf(index, maxBarWidth: maxBarWidth, colors: colors),
    t,
  );

  /// 换锚点 / 换视口当前轮：此刻的样子记成起点，新的目标记成目标，返回一个新的
  /// 场（过渡从头走）。
  ///
  /// [t] 是调用时刻的过渡进度——它不一定走完（鼠标快速扫过时上一段还在半路），
  /// 所以起点必须按**此刻**的视觉抄，不能按上一档的目标抄，否则会有一次可见的
  /// 跳变。
  _BarField retarget({
    required int? anchor,
    required int currentIndex,
    required double t,
    required int rows,
    required double maxBarWidth,
    required AthenaColors colors,
  }) {
    final candidates = <int>{
      ...origin.keys,
      ..._around(anchor, rows),
      ..._around(this.anchor, rows),
      ..._around(currentIndex, rows),
      ..._around(this.currentIndex, rows),
    };
    final resting = restingVisual(maxBarWidth: maxBarWidth, colors: colors);
    final kept = <int, _BarVisual>{};
    for (final index in candidates) {
      final visual = visualOf(
        index,
        t: t,
        maxBarWidth: maxBarWidth,
        colors: colors,
      );
      // 正好落在静止态的条不进起点表：它在整段过渡里都不会变
      if (visual != resting) kept[index] = visual;
    }
    return _BarField(origin: kept, anchor: anchor, currentIndex: currentIndex);
  }

  /// 会被某个锚点带动的那几条（± [TurnIndicator.falloffSpread]），夹在
  /// `[0, rows)` 内。
  static Iterable<int> _around(int? index, int rows) sync* {
    if (index == null || rows <= 0) return;
    final from = math.max(0, index - TurnIndicator.falloffSpread);
    final to = math.min(rows - 1, index + TurnIndicator.falloffSpread);
    for (var i = from; i <= to; i++) {
      yield i;
    }
  }
}

class _TurnIndicatorState extends State<TurnIndicator>
    with SingleTickerProviderStateMixin {
  /// hover 锚点，整段会话的下标：窗口里的条与未加载的历史条都能当锚点。
  int? _hoveredIndex;

  /// 视口当前轮，**整段会话**的下标（[TurnNavigator.currentTurnIndex] 报的是
  /// 窗口内的下标，要加上窗口首轮的位置；-1 = 还没测出来、或本次没有轮次）。
  int get _absoluteCurrentTurn {
    final windowIndex = widget.navigator.currentTurnIndex.value;
    return windowIndex < 0 ? -1 : widget.firstTurnIndex + windowIndex;
  }

  Timer? _previewTimer;
  final Map<int, GlobalKey> _barKeys = {};
  late final AnimationController _lengthController;
  late _BarField _field;

  /// 整列画多少行 = 窗口那几轮 + 未加载的历史。窗口首轮的下标大于扫描到的
  /// 总轮数时以窗口为准——新发出的消息先落进窗口、扫描还没跟上时会这样。
  int get _rowCount =>
      math.max(widget.totalTurns, widget.firstTurnIndex + widget.turns.length);

  /// 已加载窗口在整段会话里的下标区间（左闭右开）。
  int get _windowStart => widget.firstTurnIndex;
  int get _windowEnd => widget.firstTurnIndex + widget.turns.length;

  bool _isLoaded(int absoluteIndex) =>
      absoluteIndex >= _windowStart && absoluteIndex < _windowEnd;

  /// 当前的过渡进度（与 [AnimationController] 同一条曲线：全站 hover 过渡的
  /// easeOut）。
  double get _lengthT => Curves.easeOut.transform(_lengthController.value);

  @override
  void initState() {
    super.initState();
    _field = _BarField(currentIndex: _absoluteCurrentTurn);
    _lengthController = AnimationController(
      vsync: this,
      duration: TurnIndicator.barDuration,
    )..value = 1;
    widget.navigator.currentTurnIndex.addListener(_handleCurrentTurnChanged);
  }

  @override
  void didUpdateWidget(covariant TurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final navigatorChanged = !identical(oldWidget.navigator, widget.navigator);
    if (navigatorChanged) {
      oldWidget.navigator.currentTurnIndex.removeListener(
        _handleCurrentTurnChanged,
      );
      widget.navigator.currentTurnIndex.addListener(_handleCurrentTurnChanged);
    }
    final windowChanged =
        navigatorChanged ||
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
    // 行的下标口径整个变了，锚点也换了位置：不做补间，直接落到新目标
    _barKeys.clear();
    _lengthController.value = 1;
    _field = _BarField(
      anchor: _hoveredIndex,
      currentIndex: _absoluteCurrentTurn,
    );
  }

  @override
  void dispose() {
    widget.navigator.currentTurnIndex.removeListener(_handleCurrentTurnChanged);
    _previewTimer?.cancel();
    DesktopChatPreviewManager.instance.dismissFor(this);
    _lengthController.dispose();
    super.dispose();
  }

  GlobalKey _barKey(int absoluteIndex) => _barKeys.putIfAbsent(
    absoluteIndex,
    () => GlobalKey(debugLabel: 'turn-bar-$absoluteIndex'),
  );

  /// 换锚点 / 视口当前轮：整列从此刻的视觉补间到新目标。
  void _retarget({required int? anchor}) {
    _field = _field.retarget(
      anchor: anchor,
      currentIndex: _absoluteCurrentTurn,
      t: _lengthT,
      rows: _rowCount,
      maxBarWidth: widget.maxBarWidth,
      colors: Theme.of(context).extension<AthenaColors>()!,
    );
  }

  /// 视口当前轮变了：高亮跟着走，走同一段过渡。
  void _handleCurrentTurnChanged() {
    if (_absoluteCurrentTurn == _field.currentIndex) return;
    setState(() => _retarget(anchor: _hoveredIndex));
    _lengthController.forward(from: 0);
  }

  /// 指针停在某一轮上（窗口里的条与未加载的历史条都调到这里）。
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
    setState(() {
      _hoveredIndex = absoluteIndex;
      _retarget(anchor: absoluteIndex);
    });
    _lengthController.forward(from: 0);
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

  /// 指针纵坐标落在这一段里的哪一条上（整段会话的下标）。
  int _rowAt(
    Offset localPosition,
    int startAbsoluteIndex,
    int count,
    double rowHeight,
  ) {
    if (rowHeight <= 0) return startAbsoluteIndex;
    final offset = (localPosition.dy / rowHeight).floor().clamp(0, count - 1);
    return startAbsoluteIndex + offset;
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
        // 行高按整段会话的轮数收缩，永远铺得下：旧版固定 12 高，轮次一多就
        // RenderFlex overflow（实测 40 条在 300 高里溢出 180）。代价是很长
        // 的会话里条变密、命中区变窄——那时它的作用是位置图，不是精确点选。
        final rows = _rowCount;
        final rowHeight = rows <= 0 || !constraints.hasBoundedHeight
            ? TurnIndicator.barRowHeight
            : math.min(
                TurnIndicator.barRowHeight,
                constraints.maxHeight / rows,
              );
        final unloadedBefore = math.max(0, _windowStart);
        final unloadedAfter = math.max(0, rows - _windowEnd);
        // 长度与颜色随 hover 锚点和视口当前轮变，两者都由这一条控制器补间
        return AnimatedBuilder(
          animation: _lengthController,
          builder: (context, _) {
            final t = _lengthT;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unloadedBefore > 0)
                  _buildUnloadedBars(colors, unloadedBefore, 0, rowHeight, t),
                for (var index = 0; index < widget.turns.length; index++)
                  _buildBar(
                    colors,
                    widget.firstTurnIndex + index,
                    rowHeight,
                    t,
                  ),
                if (unloadedAfter > 0)
                  _buildUnloadedBars(
                    colors,
                    unloadedAfter,
                    _windowEnd,
                    rowHeight,
                    t,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 未加载的历史轮次：长度与颜色照 [_BarField] 走，与窗口里的条同一套公式，
  /// 只是没有内容可预览。
  ///
  /// 连成一段一次画完，不为每条建控件——条数可能上百上千，而整列每次都会被
  /// 重建（视口当前轮一变、hover 一动就重画）。轮数密到亚像素时它们自然并成
  /// 一条连续的轨。
  ///
  /// 它们照样是 hover 的锚点：指针停在哪一条（由行高换算，所以不必为每行建
  /// 控件）哪一条最长，相邻的按距离递减——只是不弹预览卡。点它由宿主先把历史
  /// 翻页补进来，再滚过去。
  Widget _buildUnloadedBars(
    AthenaColors colors,
    int count,
    int startAbsoluteIndex,
    double rowHeight,
    double t,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => _setHovered(
        _rowAt(event.localPosition, startAbsoluteIndex, count, rowHeight),
      ),
      onHover: (event) => _setHovered(
        _rowAt(event.localPosition, startAbsoluteIndex, count, rowHeight),
      ),
      onExit: (_) => _setHovered(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(
          _rowAt(details.localPosition, startAbsoluteIndex, count, rowHeight),
        ),
        child: CustomPaint(
          size: Size(widget.maxBarWidth, count * rowHeight),
          painter: _TurnBarsPainter(
            field: _field,
            t: t,
            startIndex: startAbsoluteIndex,
            count: count,
            maxBarWidth: widget.maxBarWidth,
            rowHeight: rowHeight,
            colors: colors,
          ),
        ),
      ),
    );
  }

  Widget _buildBar(
    AthenaColors colors,
    int absoluteIndex,
    double rowHeight,
    double t,
  ) {
    final visual = _field.visualOf(
      absoluteIndex,
      t: t,
      maxBarWidth: widget.maxBarWidth,
      colors: colors,
    );
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
            child: Container(
              key: _barKey(absoluteIndex),
              width: visual.width,
              // 行变矮时条也跟着变薄，密到极限时仍留一条可见的线
              height: math.min(TurnIndicator.barHeight, rowHeight * 0.6),
              decoration: BoxDecoration(
                color: visual.color,
                borderRadius: BorderRadius.circular(AthenaRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 未加载的历史轮次：一段一次画完。
///
/// 几何与颜色一律向 [_BarField] 要（与窗口里那些条共用同一套公式与同一段过渡），
/// 这里的职责只有"把 n 条摆成一行一条"。
class _TurnBarsPainter extends CustomPainter {
  final _BarField field;
  final double t;
  final int startIndex;
  final int count;
  final double maxBarWidth;
  final double rowHeight;
  final AthenaColors colors;

  const _TurnBarsPainter({
    required this.field,
    required this.t,
    required this.startIndex,
    required this.count,
    required this.maxBarWidth,
    required this.rowHeight,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = math.min(TurnIndicator.barHeight, rowHeight * 0.6);
    final radius = Radius.circular(barHeight / 2);
    final paint = Paint();
    for (var offset = 0; offset < count; offset++) {
      final visual = field.visualOf(
        startIndex + offset,
        t: t,
        maxBarWidth: maxBarWidth,
        colors: colors,
      );
      if (visual.width <= 0) continue;
      final top = offset * rowHeight + (rowHeight - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, visual.width, barHeight),
          radius,
        ),
        paint..color = visual.color,
      );
    }
  }

  @override
  bool shouldRepaint(_TurnBarsPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.startIndex != startIndex ||
      oldDelegate.count != count ||
      oldDelegate.maxBarWidth != maxBarWidth ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.colors != colors ||
      !identical(oldDelegate.field, field);
}
