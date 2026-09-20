import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 助手消息列表的懒构建与流式增量成本回归。
///
/// 背景：助手消息曾合并成"整卡一个列表项"（为了一张卡只画一次底板），代价是
/// 视口碰到整卡就要构建并按帧遍历卡内全部消息——实测流式增量 n=50/100/200/400
/// 分别为 27/36/109/369ms（debug、flutter_test 无 GPU），而逐消息一个列表项
/// 恒为 4-5ms；卡内记忆化确实命中（400 段里只有 3 个内容子树重建）也无法把增量
/// 降到 O(1)。不画底板后改为每条消息一个列表项，视口外的消息不再构建。
///
/// 本文件用**结构性断言**守住这个性质（不依赖计时的绝对值，避免 CI 抖动）：
/// 构建量与重建量都只与视口内的消息数有关，不随卡内消息数放大。
MessageEntity assistantMessage(int index, {String suffix = ''}) =>
    MessageEntity(
      id: index,
      chatId: 1,
      role: 'assistant',
      content:
          '第 $index 段回复。\n\n'
          '这是第二段正文，用来让 markdown 解析有一定工作量。\n\n'
          '- 要点一\n- 要点二\n$suffix',
      reasoningContent: '进度 $index 的推理内容',
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 2)),
      toolCalls: jsonEncode([
        {
          'id': 'call-$index',
          'name': 'bash',
          'arguments': jsonEncode({'command': 'echo $index'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-$index', 'name': 'bash', 'result': 'result $index'},
      ]),
    );

/// 生产路径里 sentinel 来自 ValueNotifier.value，跨帧是同一个实例。
final stableSentinel = SentinelEntity(name: 'T', avatar: 'T');

Future<void> pump(
  WidgetTester tester,
  List<MessageEntity> messages, {
  double height = 600,
  SentinelEntity? sentinel,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(900 * 2, height * 2);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AthenaColors.dark]),
      home: Scaffold(
        backgroundColor: AthenaColors.dark.surface,
        body: SizedBox(
          width: 900,
          height: height,
          child: CustomScrollView(
            slivers: [
              MessageCardListSliver(
                messages: messages,
                sentinel: sentinel ?? stableSentinel,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 统计某次 pump 期间重建了哪些 widget。
Future<Map<String, int>> rebuiltDuring(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final lines = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) lines.add(message);
  };
  debugPrintRebuildDirtyWidgets = true;
  try {
    await body();
  } finally {
    debugPrintRebuildDirtyWidgets = false;
    debugPrint = original;
  }
  int count(String needle) =>
      lines.where((line) => line.contains(needle)).length;
  return {
    '重建行': lines.length,
    '段': count('_AssistantMessageSegment'),
    '消息内容': count('_AssistantMessageContent'),
    'markdown': count('AthenaMarkdown'),
  };
}

void main() {
  testWidgets('长卡只构建视口内的消息：构建量不随消息数放大', (tester) async {
    for (final n in [50, 100, 200, 400]) {
      final messages = [for (var i = 0; i < n; i++) assistantMessage(i)];
      await pump(tester, messages);
      await tester.pump();
      final built = find.byType(AthenaMarkdown).evaluate().length;
      debugPrint('[构建量] n=$n 树内 markdown $built 个');
      expect(built, greaterThan(0));
      // 视口 + cacheExtent 覆盖的范围有限：与 n 无关，取一个宽松上界
      expect(built, lessThan(30), reason: 'n=$n 时构建了 $built 个正文，说明又变成整卡一次性构建了');
    }
  });

  testWidgets('一次流式增量只重建视口内的消息', (tester) async {
    for (final n in [100, 400]) {
      final messages = [for (var i = 0; i < n; i++) assistantMessage(i)];
      await pump(tester, messages);
      await tester.pump();

      final last = messages.length - 1;
      final stats = await rebuiltDuring(tester, () async {
        messages[last] = assistantMessage(last, suffix: 'delta');
        await pump(tester, messages);
        await tester.pump();
      });
      debugPrint('[重建量] n=$n $stats');
      // 重建的是视口内的那几段，而不是卡内全部消息
      expect(stats['段']!, lessThan(30));
      expect(stats['消息内容']!, lessThan(30));
      expect(stats['markdown']!, lessThan(30));
    }
  });

  testWidgets('首帧与流式增量耗时（诊断输出，不作断言）', (tester) async {
    for (final n in [50, 100, 200, 400]) {
      final messages = [for (var i = 0; i < n; i++) assistantMessage(i)];
      await pump(tester, [assistantMessage(999)]);
      var first = 1 << 30;
      for (var t = 0; t < 3; t++) {
        await pump(tester, [assistantMessage(999)]);
        await tester.pump();
        final sw = Stopwatch()..start();
        await pump(tester, messages);
        await tester.pump();
        sw.stop();
        if (sw.elapsedMilliseconds < first) first = sw.elapsedMilliseconds;
      }
      await pump(tester, messages);
      await tester.pump();
      final last = messages.length - 1;
      var best = 1 << 30;
      for (var t = 0; t < 3; t++) {
        // 计时前先复位成"未增长"并渲染完成：否则第 2、3 次迭代的输入已等于当前
        // 画面，测到的是无视觉变化的空转帧（这条口径错误曾让本轮得出错误结论）
        messages[last] = assistantMessage(last);
        await pump(tester, messages);
        await tester.pump();

        messages[last] = assistantMessage(last, suffix: 'delta');
        final sw = Stopwatch()..start();
        await pump(tester, messages);
        await tester.pump();
        sw.stop();
        if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds;
      }
      debugPrint('[耗时] n=$n 首帧 ${first}ms 流式增量 ${best}ms');
    }
  });
}
