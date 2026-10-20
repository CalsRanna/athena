import 'dart:math' as math;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 输入框工具栏最右的上下文占用指示器。
///
/// 12 圆环表示上下文窗口占用率，≥ 80% 用警示色；hover 给一句深色 tooltip
/// （`Context 181.6k / 1M (18%)`）和 ghost 底色（与其他控件同一份
/// [AthenaGhostButton] 实现），点击才在圆环上方弹出明细面板（标题行 +
/// 分段占用条 + 缓存命中 / 未命中 / 剩余三行图例）。
///
/// 圆环只有 12，但 hover 底与点击区域是 28 方盒：底要够大才摸得到、也才和
/// 同一行其他控件的命中区一致。方盒中心比圆环偏右 8，所以宿主让这一格整体
/// 左移 8，使底的右缘与上方输入容器对齐。
///
/// **始终占位、始终可点**：没有数据时画一圈空轨道（弧为 0），不摘控件——
/// 这格在最右侧，来回显隐会让同一行的控件横向跳动。数据缺口有两种来源，
/// tooltip 与面板都如实说明而不是编造数字：没有会话（还没跑过推理）按 0
/// 计；模型没配上下文窗口时窗口未知，占用率无从计算。
///
/// 只看上下文：数据是最近一次推理的 prompt token 快照（`chat.contextTokens`）
/// 及其中的缓存命中数，不统计会话累计用量。回退后该字段是
/// [ChatEntity.unknownContextTokens]（-1），同样按 0 计。
class DesktopTokenIndicator extends StatefulWidget {
  const DesktopTokenIndicator({super.key});

  @override
  State<DesktopTokenIndicator> createState() => _DesktopTokenIndicatorState();
}

class _DesktopTokenIndicatorState extends State<DesktopTokenIndicator> {
  final viewModel = GetIt.instance.get<ChatViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final chat = viewModel.currentChat.value;
      // 负数只出现在回退后的"未知"，与"还没跑过推理"一样按 0 展示
      final used = math.max(chat?.contextTokens ?? 0, 0);
      final window = math.max(
        viewModel.currentModel.value?.contextWindow ?? 0,
        0,
      );
      final stats = _ContextStats(
        used: used,
        window: window,
        cached: (chat?.cachedTokens ?? 0).clamp(0, used),
      );
      return _buildRing(context, stats);
    });
  }

  Widget _buildRing(BuildContext context, _ContextStats stats) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final ring = SizedBox.square(
      dimension: 12,
      child: CircularProgressIndicator(
        value: stats.ratio,
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        backgroundColor: colors.border,
        color: stats.nearLimit ? colors.statusWarning : colors.textSecondary,
        semanticsLabel: 'Context window usage',
        // 进度控件的语义值只能是数字（框架按 min/max 解析它），摘要文本
        // 放在 tooltip 里；这里给百分比，读屏才报得出「用了多少」。
        semanticsValue: _percent(stats.used, stats.window),
      ),
    );
    // tooltip 是深色底白字的一句话，明细留给点击。
    return Tooltip(
      message: 'Context ${stats.summary}',
      preferBelow: false,
      verticalOffset: 16,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      textStyle: AthenaTextStyle.caption.copyWith(color: colors.textOnRaised),
      // 12 圆环 + 8 内边距 = 28 方盒，与同一行的 ghost 控件同档
      child: AthenaGhostButton(
        onTap: () => _openDetails(stats),
        padding: const EdgeInsets.all(8),
        child: ring,
      ),
    );
  }

  /// 面板右边与圆环右边对齐、底边离圆环顶 8，向上展开。
  void _openDetails(_ContextStats stats) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    const contentWidth = 288.0;
    // 面板自带 4 内边距，左边要比"右对齐"再让出 8
    final panel = DesktopContextMenu(
      offset: Offset(anchor.right - contentWidth - 8, anchor.top - 8),
      upward: true,
      width: contentWidth,
      children: [_ContextDetails(stats: stats)],
    );
    DesktopContextMenuManager.instance.show(context, panel);
  }
}

/// 一次推理的上下文占用快照及其派生量。
class _ContextStats {
  final int used;
  final int window;
  final int cached;

  const _ContextStats({
    required this.used,
    required this.window,
    required this.cached,
  });

  /// 模型没配上下文窗口：占用率无从计算，圆环只有空轨道。
  bool get windowUnknown => window <= 0;

  int get uncached => used - cached;
  int get free => math.max(window - used, 0);
  double get ratio => windowUnknown ? 0 : (used / window).clamp(0.0, 1.0);
  bool get nearLimit => !windowUnknown && ratio >= 0.8;

  /// `181.6k / 1M (18%)`，tooltip 与面板标题共用。窗口未知时只说用了多少。
  String get summary => windowUnknown
      ? '${_compact(used)} (window unknown)'
      : '${_compact(used)} / ${_compact(window)} (${_percent(used, window)})';
}

/// 紧凑计数：千以下原样，千位一位小数带 `k`，百万带 `M`，去掉 `.0`。
String _compact(int value) {
  if (value < 1000) return '$value';
  var scaled = value / 1000;
  var unit = 'k';
  // 999.95k 起一位小数会进成 1000.0k，直接换到 M
  if (scaled >= 999.95) {
    scaled = value / 1000000;
    unit = 'M';
  }
  final text = scaled.toStringAsFixed(1);
  final trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return '$trimmed$unit';
}

/// 整数百分比；有量但不足 1% 时给 `<1%` 而不是误导性的 `0%`。
String _percent(int part, int whole) {
  if (whole <= 0 || part <= 0) return '0%';
  final pct = (part / whole * 100).round();
  return pct == 0 ? '<1%' : '$pct%';
}

/// 明细面板：标题行、分段占用条、三行图例。
/// 宽度取 [DesktopContextMenuConfiguration]，样式与右键菜单同一套浮层。
class _ContextDetails extends StatelessWidget {
  final _ContextStats stats;
  const _ContextDetails({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 缓存命中用全站唯一的强调色；未命中沿用圆环色，接近上限时同样转警示
    final cachedColor = colors.accent;
    final uncachedColor = stats.nearLimit
        ? colors.statusWarning
        : colors.textSecondary;
    final freeColor = colors.border;
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final titleStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    final header = Row(
      children: [
        Expanded(child: Text('Context window', style: titleStyle)),
        Text(stats.summary, style: titleStyle),
      ],
    );
    final bar = SizedBox(
      height: 6,
      child: CustomPaint(
        painter: _UsageBarPainter(
          track: freeColor,
          // 窗口未知时没有任何可信的分母，整条留空轨道
          segments: stats.windowUnknown
              ? const []
              : [
                  (stats.cached / stats.window, cachedColor),
                  (stats.uncached / stats.window, uncachedColor),
                ],
        ),
      ),
    );
    final rows = [
      _LegendRow(
        color: cachedColor,
        label: 'Cached',
        tokens: stats.cached,
        window: stats.window,
      ),
      _LegendRow(
        color: uncachedColor,
        label: 'Uncached',
        tokens: stats.uncached,
        window: stats.window,
      ),
      _LegendRow(
        color: freeColor,
        label: 'Free',
        tokens: stats.free,
        window: stats.window,
      ),
    ];
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: 10),
            bar,
            const SizedBox(height: 10),
            Container(height: 1, color: colors.border),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// 图例行：色点 + 名称 + 数量 + 占比。
class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int tokens;
  final int window;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.tokens,
    required this.window,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final labelStyle = AthenaTextStyle.body.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final valueStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: labelStyle)),
          Text(_compact(tokens), style: valueStyle),
          SizedBox(
            width: 40,
            child: Text(
              // 窗口未知时占比无从计算，用 `—` 而不是 0%：0% 会被读成"量为零"
              window <= 0 ? '—' : _percent(tokens, window),
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分段占用条：整条圆角轨道上按比例依次铺各段，段间留 1 逻辑像素的缝。
class _UsageBarPainter extends CustomPainter {
  final Color track;
  final List<(double, Color)> segments;
  const _UsageBarPainter({required this.track, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
    );
    canvas.drawRect(rect, Paint()..color = track);
    var x = 0.0;
    var first = true;
    for (final (fraction, color) in segments) {
      final width = size.width * fraction;
      if (width <= 0) continue;
      final gap = first ? 0.0 : 1.0;
      canvas.drawRect(
        Rect.fromLTWH(x + gap, 0, math.max(width - gap, 0), size.height),
        Paint()..color = color,
      );
      x += width;
      first = false;
    }
  }

  @override
  bool shouldRepaint(_UsageBarPainter oldDelegate) =>
      oldDelegate.track != track || !listEquals(oldDelegate.segments, segments);
}
