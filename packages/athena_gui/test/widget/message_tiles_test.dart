import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 9, 29, 12);
  final statistics = RunStatistics(id: 'run-1', startedAt: startedAt);

  MessageEntity message({
    String id = 'assistant-1',
    String role = 'assistant',
    String content = '',
    RunStatistics? runStatistics,
  }) => MessageEntity(
    id: id,
    chatId: 'chat-1',
    role: role,
    content: content,
    runStatistics: runStatistics,
  );

  Future<void> pumpMessages(
    WidgetTester tester,
    List<MessageEntity> messages, {
    bool streaming = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAthenaThemeData(AthenaColorMode.light),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            MessageCardListSliver(
              messages: messages,
              loading: streaming,
              sentinel: SentinelEntity(name: 'Athena'),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('首个 delta 前工具条常显，输出后保留指示器且更新累计 token', (tester) async {
    final assistant = message(runStatistics: statistics);
    await pumpMessages(tester, [assistant]);
    expect(find.byType(StreamingIndicator), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing);
    expect(find.textContaining('0 tokens'), findsOneWidget);
    expect(
      tester.widget<MessageActionBar>(find.byType(MessageActionBar)).visible,
      isTrue,
    );
    final initialHeight = tester.getSize(find.byType(MessageActionBar)).height;

    await pumpMessages(tester, [
      assistant.copyWith(content: 'First answer'),
      message(
        id: 'assistant-2',
        content: 'Second answer',
        runStatistics: statistics.withUsage(
          const TokenUsage(
            promptTokens: 100,
            completionTokens: 245,
            totalTokens: 345,
            outputDuration: Duration(seconds: 50),
          ),
        ),
      ),
    ]);
    expect(find.byType(MessageActionBar), findsOneWidget);
    expect(find.byType(StreamingIndicator), findsOneWidget);
    expect(find.textContaining('0 tokens'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('123 tokens'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('245 tokens'), findsOneWidget);
    expect(find.textContaining('245 tokens · 4.9 tokens/s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('245 tokens · 4.9 tokens/s'), findsOneWidget);
    expect(tester.getSize(find.byType(MessageActionBar)).height, initialHeight);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('完成后替换为复制，冻结耗时与累计 token，复制整次 run', (tester) async {
    final first = message(content: 'First answer', runStatistics: statistics);
    final last = message(
      id: 'assistant-2',
      content: 'Second answer',
      runStatistics: statistics.withUsage(
        const TokenUsage(
          promptTokens: 100,
          completionTokens: 245,
          totalTokens: 345,
          outputDuration: Duration(seconds: 50),
        ),
      ),
    );
    await pumpMessages(tester, [first, last]);
    final height = tester.getSize(find.byType(MessageActionBar)).height;
    final done = last.copyWith(
      runStatistics: last.runStatistics!.copyWith(
        finishedAt: startedAt.add(const Duration(seconds: 65)),
      ),
    );
    await pumpMessages(tester, [first, done], streaming: false);
    expect(find.byType(StreamingIndicator), findsNothing);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.text('1m 5s · 245 tokens · 4.9 tokens/s'), findsOneWidget);
    expect(tester.getSize(find.byType(MessageActionBar)).height, height);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    await mouse.moveTo(tester.getCenter(find.text('First answer')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MessageActionBar>(find.byType(MessageActionBar)).visible,
      isTrue,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.tap(find.byTooltip('Copy'));
    expect(copied, 'First answer\n\nSecond answer');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('1m 5s · 245 tokens · 4.9 tokens/s'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('相邻的不同 run 不混用工具条与统计，用户消息仍按 hover 显示', (tester) async {
    await pumpMessages(tester, [
      message(id: 'user-1', role: 'user', content: 'Question'),
      message(
        content: 'Completed answer',
        runStatistics: statistics
            .withUsage(
              const TokenUsage(
                promptTokens: 100,
                completionTokens: 100,
                totalTokens: 200,
                outputDuration: Duration(seconds: 10),
              ),
            )
            .copyWith(finishedAt: startedAt.add(const Duration(seconds: 10))),
      ),
      message(
        id: 'report-1',
        runStatistics: RunStatistics(id: 'run-2', startedAt: startedAt),
      ),
    ]);
    final bars = tester
        .widgetList<MessageActionBar>(find.byType(MessageActionBar))
        .toList();
    expect(bars, hasLength(3));
    expect(bars.map((bar) => bar.visible), [false, false, true]);
    expect(find.byType(StreamingIndicator), findsOneWidget);
    expect(find.text('10s · 100 tokens · 10.0 tokens/s'), findsOneWidget);
    expect(find.textContaining('· 0 tokens'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('旧消息缺少统计时显示未知值', (tester) async {
    await pumpMessages(tester, [
      message(content: 'Legacy answer'),
    ], streaming: false);
    expect(find.text('— · — tokens · — tokens/s'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
  });
}
