import 'dart:io';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/nocterm_test.dart' as nocterm_test;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_scroll_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<TuiDi> createDi() async {
    // homeDir 注入 tempDir:避免读到用户真实 ~/.athena/setting.yaml
    final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
    await di.initialize(syncModels: false);
    await di.chatController.initialize();
    return di;
  }

  test('消息超过视口后新消息自动滚到底部,推理内容可见', () {
    return nocterm_test.testNocterm('自动滚动', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      final c = di.chatController;
      // 注入 20 条消息超过视口(24 行)
      c.messages.value = [
        for (var i = 0; i < 20; i++)
          MessageEntity(
            id: i + 1,
            chatId: 1,
            role: i.isEven ? 'user' : 'assistant',
            content: '消息 $i: 一条较长的消息内容用于测试滚动。',
          ),
      ];
      await tester.pump();
      await tester.pump(); // postFrame 里的 jumpTo 应用

      // 追加新消息(模拟流式到达),带推理内容
      c.messages.value = [
        ...c.messages.value,
        MessageEntity(
          id: 21,
          chatId: 1,
          role: 'assistant',
          content: '新消息末尾',
          reasoningContent: '推理过程内容',
        ),
      ];
      await tester.pump();
      await tester.pump();

      final s = tester.terminalState;
      // 新消息在底部可见(已自动滚动)
      expect(s.containsText('新消息末尾'), isTrue);
      // 推理过程直接展示(无需展开)
      expect(s.containsText('推理过程内容'), isTrue);
      // 推理在正文之前(思考是得出答案的过程,显示在回答上方)
      final lines = s.renderToString().split('\n');
      final reasoningLine =
          lines.indexWhere((l) => l.contains('推理过程内容'));
      final contentLine = lines.indexWhere((l) => l.contains('新消息末尾'));
      expect(reasoningLine, isNonNegative);
      expect(contentLine, isNonNegative);
      expect(reasoningLine, lessThan(contentLine));
      // 顶部首条消息已滚出视口(证明真的滚动了)
      expect(s.containsText('消息 0:'), isFalse);
    });
  });

  test('用户向上翻阅后新消息不自动滚底', () {
    return nocterm_test.testNocterm('不打扰滚动', (tester) async {
      final di = await createDi();
      // 注入外部 controller:测试中模拟用户滚动后仍能读取其状态
      final scroll = nocterm.ScrollController();
      await tester.pumpComponent(AthenaApp(di: di, scrollController: scroll));
      await tester.pump();

      final c = di.chatController;
      c.messages.value = [
        for (var i = 0; i < 20; i++)
          MessageEntity(
            id: i + 1,
            chatId: 1,
            role: 'user',
            content: '消息 $i',
          ),
      ];
      await tester.pump();
      await tester.pump(); // 滚到底

      // 用户向上翻阅(回顶部):触发 listener → sticky=false
      scroll.jumpTo(0);
      await tester.pump();

      // 追加新消息:不应打扰用户,仍在顶部附近
      c.messages.value = [
        ...c.messages.value,
        MessageEntity(id: 21, chatId: 1, role: 'user', content: '最后一条'),
      ];
      await tester.pump();
      await tester.pump(); // postFrame 若无 jumpTo 则位置不变

      final s = tester.terminalState;
      expect(s.containsText('最后一条'), isFalse, reason: '用户上翻后不应自动滚底');
      expect(s.containsText('消息 0'), isTrue, reason: '视口应停留在顶部');
    });
  });
}
