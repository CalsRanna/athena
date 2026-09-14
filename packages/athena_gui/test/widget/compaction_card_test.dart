import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/compaction_card.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CompactionStep _step(CompactionPhase phase) => CompactionStep(
  messageId: 8,
  chatId: 1,
  runId: 1,
  phase: phase,
  startedAt: DateTime(2026, 9, 14),
  beforeTokens: 80000,
  afterTokens: phase == CompactionPhase.completed ? 9000 : null,
  messageCount: 24,
  summary: phase == CompactionPhase.completed ? '已完成检查；接下来修复测试。' : '',
  error: phase == CompactionPhase.failed ? '摘要服务暂时不可用，原上下文保留。' : null,
  finishedAt:
      [
        CompactionPhase.completed,
        CompactionPhase.failed,
        CompactionPhase.cancelled,
      ].contains(phase)
      ? DateTime(2026, 9, 14, 0, 0, 3)
      : null,
);

void main() {
  Future<void> pumpStep(
    WidgetTester tester,
    CompactionPhase phase, {
    bool isLive = true,
    double width = 360,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AthenaColors.dark]),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: CustomScrollView(
              slivers: [
                MessageCardListSliver(
                  messages: [_step(phase).toMessage()],
                  loading: isLive,
                  sentinel: SentinelEntity(name: 'Athena', avatar: 'A'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'one card survives phase changes, finishes collapsed, and opens details',
    (tester) async {
      await pumpStep(tester, CompactionPhase.triggered);
      final identity = tester.state(find.byType(CompactionCard));
      expect(find.textContaining('准备压缩'), findsOneWidget);
      await pumpStep(tester, CompactionPhase.summarizing);
      expect(
        identical(tester.state(find.byType(CompactionCard)), identity),
        isTrue,
      );
      expect(find.byType(CompactionCard), findsOneWidget);
      expect(
        tester.widget<ToolHeaderShimmer>(find.byType(ToolHeaderShimmer)).active,
        isTrue,
      );
      await tester.tap(find.textContaining('正在压缩上下文'));
      await tester.pump();
      expect(find.byType(SelectableText), findsOneWidget);
      await pumpStep(tester, CompactionPhase.persisting);
      expect(find.textContaining('正在保存摘要'), findsOneWidget);
      await pumpStep(tester, CompactionPhase.completed);
      expect(
        identical(tester.state(find.byType(CompactionCard)), identity),
        isTrue,
      );
      expect(find.text('约 80000 → 9000 tokens'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(
        tester.widget<ToolHeaderShimmer>(find.byType(ToolHeaderShimmer)).active,
        isFalse,
      );
      await tester.tap(find.textContaining('压缩完成'));
      await tester.pump();
      expect(find.textContaining('已完成检查；接下来修复测试。'), findsOneWidget);
      expect(find.textContaining('覆盖 24 条消息'), findsOneWidget);
      expect(find.textContaining('耗时 3.0 秒'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phase in [CompactionPhase.failed, CompactionPhase.cancelled]) {
    testWidgets('$phase stops animation and stays on one card', (tester) async {
      await pumpStep(tester, CompactionPhase.summarizing);
      await pumpStep(tester, phase);
      expect(find.byType(CompactionCard), findsOneWidget);
      expect(
        tester.widget<ToolHeaderShimmer>(find.byType(ToolHeaderShimmer)).active,
        isFalse,
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(find.byType(SelectableText), findsOneWidget);
      if (phase == CompactionPhase.failed) {
        expect(find.textContaining('摘要服务暂时不可用'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'reopened completed card has details and interrupted work does not animate',
    (tester) async {
      await pumpStep(tester, CompactionPhase.completed, isLive: false);
      expect(find.textContaining('压缩完成'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(find.textContaining('已完成检查'), findsOneWidget);
      await pumpStep(tester, CompactionPhase.summarizing, isLive: false);
      expect(find.textContaining('压缩已中断'), findsOneWidget);
      expect(
        tester.widget<ToolHeaderShimmer>(find.byType(ToolHeaderShimmer)).active,
        isFalse,
      );
    },
  );

  testWidgets('narrow mobile card wraps without overflow', (tester) async {
    await pumpStep(tester, CompactionPhase.completed, width: 240);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CompactionCard), findsOneWidget);
  });
}
