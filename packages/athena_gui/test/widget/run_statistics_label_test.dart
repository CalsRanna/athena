import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_gui/component/run_statistics_label.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 9, 29, 12);

  Future<void> pumpStatistics(
    WidgetTester tester, {
    int? tokens,
    double? rate,
    bool streaming = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAthenaThemeData(AthenaColorMode.light),
      home: Scaffold(
        body: RunStatisticsLabel(
          statistics: RunStatistics(
            id: 'run-1',
            startedAt: startedAt,
            finishedAt: streaming
                ? null
                : startedAt.add(const Duration(seconds: 10)),
            outputTokens: tokens,
            outputTokensPerSecond: rate,
          ),
          streaming: streaming,
        ),
      ),
    ),
  );

  testWidgets('数字在 500ms 内渐变，连续更新从显示值接续，完成 run 不打断', (tester) async {
    await pumpStatistics(tester, tokens: 1000, rate: 20);
    expect(find.textContaining('1,000 tokens · 20.0 tokens/s'), findsOneWidget);
    await pumpStatistics(tester, tokens: 2000, rate: 40);
    expect(find.textContaining('1,000 tokens · 20.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('1,500 tokens · 30.0 tokens/s'), findsOneWidget);

    await pumpStatistics(tester, tokens: 3000, rate: 10);
    expect(find.textContaining('1,500 tokens · 30.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('2,250 tokens · 20.0 tokens/s'), findsOneWidget);

    await pumpStatistics(tester, tokens: 3000, rate: 10, streaming: false);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('10s · 3,000 tokens · 10.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('10s · 3,000 tokens · 10.0 tokens/s'), findsOneWidget);
  });

  testWidgets('耗时刷新不重启动画，千分位与简写跟随显示值', (tester) async {
    await pumpStatistics(tester, tokens: 9000, rate: 20);
    await tester.pump(const Duration(milliseconds: 800));
    await pumpStatistics(tester, tokens: 11000, rate: 40);
    expect(find.textContaining('9,000 tokens'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.textContaining('9,500 tokens · 25.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.textContaining('10K tokens · 30.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('11K tokens · 40.0 tokens/s'), findsOneWidget);

    await pumpStatistics(tester, tokens: 1989000, rate: 40);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('1M tokens · 40.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('2M tokens · 40.0 tokens/s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('缺失数值保留未知，首次上报速度不从虚构值动画', (tester) async {
    await pumpStatistics(tester, streaming: false);
    expect(find.text('10s · — tokens · — tokens/s'), findsOneWidget);
    await pumpStatistics(tester);
    expect(find.textContaining('0 tokens · — tokens/s'), findsOneWidget);
    await pumpStatistics(tester, tokens: 100, rate: 10);
    expect(find.textContaining('0 tokens · 10.0 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('50 tokens · 10.0 tokens/s'), findsOneWidget);
    await pumpStatistics(tester, tokens: 200);
    expect(find.textContaining('50 tokens · — tokens/s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
