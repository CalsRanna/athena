import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      theme: buildAthenaThemeData(
        AthenaColorMode.light,
      ).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            MessageCardListSliver(
              messages: messages,
              loading: streaming,
              sentinel: const SentinelEntity(name: 'Athena'),
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
    expect(find.textContaining('tokens'), findsNothing);
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
    expect(find.textContaining('245 tokens'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('245 tokens'), findsOneWidget);
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
    expect(find.textContaining('tokens'), findsOneWidget);
    expect(find.textContaining('— tokens'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('旧消息缺少统计时仅显示未知耗时', (tester) async {
    await pumpMessages(tester, [
      message(content: 'Legacy answer'),
    ], streaming: false);
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('tokens'), findsNothing);
    expect(find.byTooltip('Copy'), findsOneWidget);
  });

  testWidgets('工具条复制键换成勾 + Copied，3 秒复原且行高不变', (tester) async {
    await pumpMessages(tester, [
      message(id: 'user-1', role: 'user', content: 'Question'),
    ], streaming: false);
    final copies = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copies.add((call.arguments as Map)['text'] as String);
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

    // 操作条 hover 才显形，且不显形时 IgnorePointer 收不到点击
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    await mouse.moveTo(tester.getCenter(find.text('Question')));
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byType(MessageActionBar)).height;
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump(AthenaMotion.hover);
    await tester.pump();
    expect(copies, ['Question']);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('Copied'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Copied')).style?.fontSize,
      AthenaTextStyle.caption.fontSize,
      reason: '工具条的「Copied」跟着自己那行（caption），不走代码块的正文档',
    );
    expect(
      tester.getSize(find.byType(MessageActionBar)).height,
      height,
      reason: '「Copied」只该把按钮加宽，不该顶高工具条',
    );

    await tester.tap(find.text('Copied'));
    await tester.pump();
    expect(copies, ['Question'], reason: '「已复制」期间重复点击不再复制');

    await tester.pump(AthenaMotion.linger);
    await tester.pump(AthenaMotion.hover);
    await tester.pump();
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.text('Copied'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(copies, ['Question', 'Question']);

    // 复原前卸载（切换对话 / 流式重建）不能再对已销毁的 State 调 setState
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
}
