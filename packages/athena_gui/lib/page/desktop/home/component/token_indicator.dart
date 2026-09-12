import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 输入框工具栏中的 token 使用情况指示器。
///
/// 12px 圆环展示上下文窗口占用率，超过 80% 时使用警示色。
/// 悬停后展示上下文、缓存命中与会话累计用量的完整明细。
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
        context,
        cumulative: cumulative,
        ctxTokens: ctxTokens,
        ctxWindow: ctxWindow,
        cachedTokens: cachedTokens,
        hasCtx: hasCtx,
        hasCache: hasCache,
      );
    });
  }

  Widget _buildIndicator(
    BuildContext context, {
    required int cumulative,
    required int ctxTokens,
    required int ctxWindow,
    required int cachedTokens,
    required bool hasCtx,
    required bool hasCache,
  }) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final usage = hasCtx ? ctxTokens / ctxWindow : 0.0;
    final ctxPct = hasCtx
        ? ((ctxTokens / ctxWindow) * 100).toStringAsFixed(
            ctxTokens * 100 ~/ ctxWindow > 99 ? 0 : 1,
          )
        : '—';

    return Tooltip(
      richMessage: _tooltip(
        context,
        cumulative: cumulative,
        ctxTokens: ctxTokens,
        ctxWindow: ctxWindow,
        cachedTokens: cachedTokens,
        hasCtx: hasCtx,
        hasCache: hasCache,
        ctxPct: ctxPct,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      preferBelow: false,
      child: SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(
          value: usage.clamp(0.0, 1.0),
          strokeWidth: 2.5,
          strokeCap: StrokeCap.round,
          backgroundColor: colors.borderFaint.withValues(alpha: 0.25),
          color: usage >= 0.8 ? colors.statusWarning : colors.teal,
          semanticsLabel: '上下文窗口占用率',
          semanticsValue: hasCtx ? '$ctxPct%' : '暂无数据',
        ),
      ),
    );
  }

  TextSpan _tooltip(
    BuildContext context, {
    required int cumulative,
    required int ctxTokens,
    required int ctxWindow,
    required int cachedTokens,
    required bool hasCtx,
    required bool hasCache,
    required String ctxPct,
  }) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final ts = TextStyle(color: colors.textInput, fontSize: 12, height: 1.5);
    final children = <InlineSpan>[
      TextSpan(text: '上下文窗口'),
      TextSpan(
        text: hasCtx
            ? '\n已使用 $ctxPct%'
                  '\n${_brk(ctxTokens)} / ${_brk(ctxWindow)} tokens'
            : '\n暂无数据',
        style: TextStyle(color: colors.teal),
      ),
    ];
    if (hasCache) {
      children.add(
        TextSpan(
          text:
              '\n缓存命中 ${_cacheRate(cachedTokens, ctxTokens)}%'
              '（${_brk(cachedTokens)} / ${_brk(ctxTokens)}）',
          style: TextStyle(color: colors.teal),
        ),
      );
    }
    children.addAll([
      TextSpan(text: '\n\n会话累计'),
      TextSpan(
        text: '\n${_brk(cumulative)}',
        style: TextStyle(color: colors.teal),
      ),
      TextSpan(
        text: '\n口径：每轮 usage.total 都计入，含 prompt 重复计费',
        style: TextStyle(
          color: colors.textInput.withValues(alpha: 0.45),
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
}
