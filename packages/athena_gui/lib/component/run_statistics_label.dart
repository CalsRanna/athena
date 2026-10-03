import 'dart:async';

import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// The run time, cumulative output tokens and latest LLM response's output rate.
class RunStatisticsLabel extends ImplicitlyAnimatedWidget {
  final RunStatistics? statistics;
  final bool streaming;

  const RunStatisticsLabel({
    super.key,
    required this.statistics,
    required this.streaming,
  }) : super(duration: AthenaMotion.slower);

  @override
  AnimatedWidgetBaseState<RunStatisticsLabel> createState() =>
      _RunStatisticsLabelState();
}

class _RunStatisticsLabelState
    extends AnimatedWidgetBaseState<RunStatisticsLabel> {
  Timer? _timer;
  Tween<double>? _tokens;
  Tween<double>? _rate;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _tokens =
        visitor(
              _tokens,
              widget.statistics?.outputTokens?.toDouble(),
              (dynamic value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
    _rate =
        visitor(
              _rate,
              widget.statistics?.outputTokensPerSecond,
              (dynamic value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(RunStatisticsLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final statistics = widget.statistics;
    if (widget.streaming &&
        statistics != null &&
        statistics.finishedAt == null) {
      // 只刷新统计行，等待审批或工具时也计时，不重建消息正文。
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _durationLabel(Duration? elapsed) {
    if (elapsed == null) return '—';
    final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${seconds ~/ 60 % 60}m ${seconds % 60}s';
  }

  String _groupedTokens(int tokens) => tokens.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  String _compactTokens(int tokens) {
    if (tokens < 10000) return _groupedTokens(tokens);
    // 一位小数会把 999.95K 进成 1000K，因此在进位边界提前换单位。
    final (divisor, suffix) = switch (tokens) {
      >= 999950000000 => (1000000000000, 'T'),
      >= 999950000 => (1000000000, 'B'),
      >= 999950 => (1000000, 'M'),
      _ => (1000, 'K'),
    };
    final value = (tokens / divisor).toStringAsFixed(1);
    final trimmed = value.endsWith('.0')
        ? value.substring(0, value.length - 2)
        : value;
    return '$trimmed$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final statistics = widget.statistics;
    final now = DateTime.now();
    final hasDuration =
        statistics != null &&
        (widget.streaming || statistics.finishedAt != null);
    final elapsed = hasDuration ? statistics.elapsedAt(now) : null;
    final displayedTokens = _tokens?.evaluate(animation).round();
    final displayedRate = _rate?.evaluate(animation);
    final labels = [
      _durationLabel(elapsed),
      if (displayedTokens != null) '${_compactTokens(displayedTokens)} tokens',
      if (displayedRate != null) '${displayedRate.toStringAsFixed(1)} tokens/s',
    ];
    return Text(
      labels.join(' · '),
      style: athenaMono(
        color: colors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
