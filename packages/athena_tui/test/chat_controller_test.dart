import 'dart:async';
import 'dart:io';

import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:test/test.dart';

/// 流式增量合并（core 的 StreamingMessageBuffer）在 TUI 侧的接线。
///
/// 这些断言此前无处可测：TUI 只有 5 个测试，且控制器依赖整张装配图。
/// TuiDi 支持 dataDirectory / homeDir 覆盖，装配一份隔离的依赖图即可。
void main() {
  late Directory temp;
  late TuiDi di;
  late ChatController controller;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('athena_tui_controller_');
    di = TuiDi(
      dataDirectory: temp.path,
      homeDir: temp.path,
      workspace: temp.path,
    );
    controller = di.chatController;
    controller.currentChat.value = ChatEntity(
      id: 'c1',
      title: 't',
      modelId: 'm',
      sentinelId: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  });

  tearDown(() {
    controller.dispose();
    temp.deleteSync(recursive: true);
  });

  MessageEntity message(String id, {String content = '', int seq = 0}) =>
      MessageEntity(
        id: id,
        chatId: 'c1',
        role: 'assistant',
        content: content,
        seq: seq,
      );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  test('rewind 恢复输入和图片，重置窗口与用量且不发送', () async {
    await di.storage.load();
    final repo = di.storage.sessionRepository;
    final id = await repo.createChat(controller.currentChat.value!);
    final first = await repo.storeMessage(
      MessageEntity(chatId: id, role: 'user', content: 'A'),
    );
    final target = await repo.storeMessage(
      MessageEntity(chatId: id, role: 'user', content: 'B', imageUrls: 'AQID'),
    );
    await repo.storeMessage(
      MessageEntity(chatId: id, role: 'assistant', content: 'withdraw'),
    );
    await controller.selectChat((await repo.getChatById(id))!);
    final result = await controller.rewindMessage(target);
    expect(result!.input.content, 'B');
    expect(controller.messages.value.map((m) => m.id), [first.id]);
    expect(controller.pendingImageUrls.value, 'AQID');
    expect(controller.currentTokenUsage.value, isNull);
    expect(controller.currentChat.value!.contextTokens, -1);
    expect(controller.isRewinding.value, isFalse);
    expect((await repo.getMessagesByChatId(id)).map((m) => m.id), [first.id]);
  });

  test('窗口内的多次增量合并不逐条写信号', () async {
    controller.handleRunEvent(RunMessageUpdated(message('m1', content: 'a')));
    controller.handleRunEvent(RunMessageUpdated(message('m1', content: 'ab')));
    controller.handleRunEvent(RunMessageUpdated(message('m1', content: 'abc')));

    expect(controller.messages.value, isEmpty, reason: '窗口未到，还在缓冲里');

    await settle();

    expect(controller.messages.value, hasLength(1));
    expect(controller.messages.value.single.content, 'abc');
  });

  test('缓冲期间推入的瞬态消息不被整体覆盖', () async {
    // 直接写 messages.value 会被挂起的 pending 覆盖掉——pushTransientMessage
    // 必须先并入缓冲再提交。
    controller.handleRunEvent(RunMessageStored(message('m1', content: 'run')));
    expect(controller.messages.value, isEmpty);

    controller.pushTransientMessage(message('t1', content: '/help'));

    expect(controller.messages.value.map((m) => m.id), [
      'm1',
      't1',
    ], reason: '流式增量与瞬态消息都要在');
  });

  test('收尾路径也按窗口裁剪（这次合并修掉的漂移）', () {
    // 同步喂满窗口以上，不给 100ms 定时器触发机会，增量全留在缓冲里。
    const total = ChatController.messageWindowSize + 3;
    for (var i = 0; i < total; i++) {
      controller.handleRunEvent(
        RunMessageStored(message('m$i', content: 'x', seq: i)),
      );
    }
    expect(controller.messages.value, isEmpty);

    // stopGenerating 走的是收尾路径：合并前它直接写 messages.value = pending，
    // 不裁窗口，于是信号里会多出 3 条超出窗口的历史。
    controller.stopGenerating();

    expect(
      controller.messages.value,
      hasLength(ChatController.messageWindowSize),
    );
    expect(controller.messages.value.last.id, 'm${total - 1}');
  });

  test('dispose 后再推瞬态消息不写信号', () {
    controller.dispose();
    final before = controller.messages.value;

    expect(
      () => controller.pushTransientMessage(message('t1')),
      returnsNormally,
    );
    expect(controller.messages.value, same(before));
  });
}
