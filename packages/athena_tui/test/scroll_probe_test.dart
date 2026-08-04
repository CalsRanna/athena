import 'dart:io';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:nocterm/nocterm_test.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('真实 app 自动滚动 + 推理展示', () {
    return nt.testNocterm('scroll', (tester) async {
      final dir = await Directory.systemTemp.createTemp('scroll_');
      final di = TuiDi(dataDirectory: dir.path);
      await di.initialize(syncModels: false);
      await di.chatController.initialize();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      final c = di.chatController;
      // 注入 20 条消息(超过 24 行视口)
      c.messages.value = [
        for (var i = 0; i < 20; i++)
          MessageEntity(id: i + 1, chatId: 1,
            role: i.isEven ? 'user' : 'assistant',
            content: '消息 $i: 这是一条较长的消息内容用于测试滚动。'),
      ];
      await tester.pump();
      await tester.pump(); // postFrame 里的 jumpTo 应用

      // 追加新消息(模拟到达)
      c.messages.value = [...c.messages.value,
        MessageEntity(id: 21, chatId: 1, role: 'assistant',
          content: '新消息末尾', reasoningContent: '推理过程内容')];
      await tester.pump();
      await tester.pump();

      final s = tester.terminalState;
      print('=== 新消息可见: ${s.containsText('新消息末尾')}');
      print('=== 推理可见: ${s.containsText('推理过程内容')}');
      print('=== 底部3行:');
      print(s.renderToString().split('\n').sublist(20, 24).join('\n'));
      await dir.delete(recursive: true);
    });
  });
}
