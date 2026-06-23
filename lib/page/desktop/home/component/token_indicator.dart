import 'package:athena/model/token_usage.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 输入框工具栏中的 token 使用情况指示器。
///
/// 展示三类指标：
/// - 单次调用：prompt ↑ / completion ↓ / total Σ（最近一次推理）。。
/// - 缓存率：cachedTokens / promptTokens（仅当 provider 返回缓存数据）。
/// - 会话累计：当前会话所有轮次加总的 token 总量（跨重启持久化）。
///
/// 无任何数据时（无当前 usage 且累计为 0）不渲染。
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
      final usage = viewModel.currentTokenUsage.value;
      final cumulative = viewModel.cumulativeTokenTotal.value;
      if (usage == null && cumulative == 0) {
        return const SizedBox.shrink();
      }
      return _TokenIndicatorChip(usage: usage, cumulative: cumulative);
    });
  }
}

class _TokenIndicatorChip extends StatelessWidget {
  final TokenUsage? usage;
  final int cumulative;
  const _TokenIndicatorChip({required this.usage, required this.cumulative});

  @override
  Widget build(BuildContext context) {
    final hasUsage = usage != null;
    final prompt = _format(usage?.promptTokens ?? 0);
    final completion = _format(usage?.completionTokens ?? 0);
    final total = _format(usage?.totalTokens ?? 0);
    final hasCache =
        hasUsage && usage!.cachedTokens != null && usage!.promptTokens > 0;
    final style = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final dimStyle = TextStyle(
      color: ColorUtil.FFF5F5F5.withValues(alpha: 0.6),
      fontSize: 12,
    );
    final accentStyle = TextStyle(
      color: ColorUtil.FF6ABEB9,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final tooltipStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 12,
      height: 1.5,
    );
    final tooltip = TextSpan(
      style: tooltipStyle,
      children: [
        const TextSpan(
          text: '最近一次调用',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(
          text: '\nPrompt: ${usage?.promptTokens ?? 0}',
          style: TextStyle(color: ColorUtil.FFF5F5F5.withValues(alpha: 0.8)),
        ),
        TextSpan(text: '\nCompletion: ${usage?.completionTokens ?? 0}'),
        TextSpan(
          text: '\nTotal: ${usage?.totalTokens ?? 0}',
          style: TextStyle(color: ColorUtil.FF6ABEB9),
        ),
        if (usage?.reasoningTokens != null)
          TextSpan(
            text: '\nReasoning: ${usage!.reasoningTokens}',
            style: TextStyle(color: ColorUtil.FFF5F5F5.withValues(alpha: 0.8)),
          ),
        if (hasCache)
          TextSpan(
            text: '\nCache: ${usage!.cachedTokens} / '
                '${usage!.promptTokens} tokens 命中缓存',
            style: TextStyle(color: ColorUtil.FFF5F5F5.withValues(alpha: 0.8)),
          ),
        const TextSpan(text: '\n\n会话累计'),
        TextSpan(
          text: '\nTotal: $cumulative',
          style: TextStyle(color: ColorUtil.FF6ABEB9),
        ),
      ],
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HugeIcons.strokeRoundedCommandLine,
          color: ColorUtil.FFF5F5F5.withValues(alpha: 0.6),
          size: 14,
        ),
        const SizedBox(width: 6),
        Text('↑$prompt', style: style),
        const SizedBox(width: 6),
        Text('↓$completion', style: style),
        if (hasCache) ...[
          const SizedBox(width: 6),
          Text('${_cacheRate(usage!)}%', style: accentStyle),
        ],
        const SizedBox(width: 6),
        Text('Σ$total', style: dimStyle),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 12,
          color: ColorUtil.FFFFFFFF.withValues(alpha: 0.15),
        ),
        const SizedBox(width: 8),
        Text('∑${_format(cumulative)}', style: accentStyle),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.12)),
      ),
      child: Tooltip(
        richMessage: tooltip,
        decoration: BoxDecoration(
          color: ColorUtil.FF282F32,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        preferBelow: false,
        child: row,
      ),
    );
  }

  String _cacheRate(TokenUsage u) {
    final cached = u.cachedTokens ?? 0;
    if (u.promptTokens <= 0) return '0';
    final rate = (cached / u.promptTokens) * 100;
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(1);
  }

  String _format(int value) {
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}
