import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 输入框工具栏中的 token 使用情况指示器。
///
/// 与左侧的 Config/Image 图标同风格（24px 图标 + 紧凑文本），
/// 不渲染 chip 容器。展示：
/// - 上下文窗口占用率（ctx%），超过 80% 暖色提示
/// - 缓存命中率（仅 provider 返回缓存数据时）
/// - 会话累计总量（悬停 Tooltip 显完整明细）
///
/// 无任何数据时不渲染。
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
      final model = viewModel.currentModel.value;
      final cumulative = viewModel.cumulativeTokenTotal.value;
      final ctxTokens = chat?.contextTokens ?? 0;
      final ctxWindow = model?.contextWindow ?? 0;
      final cachedTokens = chat?.cachedTokens ?? 0;
      final hasCtx = ctxTokens > 0 && ctxWindow > 0;
      final hasCache = cachedTokens > 0 && ctxTokens > 0;
      if (!hasCtx && cumulative == 0) return const SizedBox.shrink();

      return _buildIndicator(
        cumulative: cumulative,
        ctxTokens: ctxTokens,
        ctxWindow: ctxWindow,
        cachedTokens: cachedTokens,
        hasCtx: hasCtx,
        hasCache: hasCache,
      );
    });
  }

  Widget _buildIndicator({
    required int cumulative,
    required int ctxTokens,
    required int ctxWindow,
    required int cachedTokens,
    required bool hasCtx,
    required bool hasCache,
  }) {
    final style = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final accentStyle = TextStyle(
      color: ColorUtil.FF6ABEB9,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // 超过 80% 用暖色提醒窗口即将耗尽。
    final over80 = hasCtx && ctxTokens / ctxWindow >= 0.8;
    final ctxPctStyle = over80
        ? accentStyle.copyWith(color: ColorUtil.FFC2C2C2)
        : accentStyle;

    final ctxPct = hasCtx
        ? ((ctxTokens / ctxWindow) * 100).toStringAsFixed(
            ctxTokens * 100 ~/ ctxWindow > 99 ? 0 : 1,
          )
        : '—';

    // 主行：ctx 占用率 + 可选 cache 率 + 累计
    final children = <Widget>[
      Text('context $ctxPct%', style: ctxPctStyle),
      if (hasCache) ...[
        const SizedBox(width: 10),
        Text(
          'cache ${_cacheRate(cachedTokens, ctxTokens)}%',
          style: accentStyle,
        ),
      ],
      const SizedBox(width: 10),
      Text('total ${_format(cumulative)}', style: style),
    ];

    final child = Row(mainAxisSize: MainAxisSize.min, children: children);
    final tooltip = Tooltip(
      richMessage: _tooltip(
        cumulative: cumulative,
        ctxTokens: ctxTokens,
        ctxWindow: ctxWindow,
        cachedTokens: cachedTokens,
        hasCtx: hasCtx,
        hasCache: hasCache,
      ),
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      preferBelow: false,
      child: child,
    );
    return MouseRegion(cursor: SystemMouseCursors.click, child: tooltip);
  }

  TextSpan _tooltip({
    required int cumulative,
    required int ctxTokens,
    required int ctxWindow,
    required int cachedTokens,
    required bool hasCtx,
    required bool hasCache,
  }) {
    final ts = TextStyle(color: ColorUtil.FFF5F5F5, fontSize: 12, height: 1.5);
    final children = <InlineSpan>[
      const TextSpan(text: '上下文窗口'),
      TextSpan(
        text: hasCtx
            ? '\n${_format(ctxTokens)} / ${_format(ctxWindow)}'
            : '\n暂无数据',
        style: TextStyle(color: ColorUtil.FF6ABEB9),
      ),
    ];
    if (hasCache) {
      children.add(
        TextSpan(
          text:
              '\n缓存命中 ${_cacheRate(cachedTokens, ctxTokens)}%'
              '（${_brk(cachedTokens)} / ${_brk(ctxTokens)}）',
          style: TextStyle(color: ColorUtil.FF6ABEB9),
        ),
      );
    }
    children.addAll([
      const TextSpan(text: '\n\n会话累计'),
      TextSpan(
        text: '\n${_brk(cumulative)}',
        style: TextStyle(color: ColorUtil.FF6ABEB9),
      ),
      TextSpan(
        text: '\n口径：每轮 usage.total 都计入，含 prompt 重复计费',
        style: TextStyle(
          color: ColorUtil.FFF5F5F5.withValues(alpha: 0.45),
          fontSize: 11,
        ),
      ),
    ]);
    return TextSpan(style: ts, children: children);
  }

  String _cacheRate(int cached, int prompt) {
    if (prompt <= 0) return '0';
    final rate = (cached / prompt) * 100;
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(1);
  }

  String _brk(int v) {
    if (v < 1000) return '$v';
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}
