import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/view_model/message_window_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_message_repo.dart';

/// 消息窗口单元的契约。
///
/// 分页那部分由 `chat_pagination_test` 从 ViewModel 的公开面覆盖；这里测的是它自己
/// 的浅层表面——尤其是流式增量与窗口替换的先后顺序：缓冲里那批增量攥着一份完整
/// 快照，谁先谁后弄反就会把消息吞掉或让旧消息回来。
void main() {
  late String? currentChatId;
  late FakeMessageRepo repository;
  late MessageWindowStore store;

  setUp(() {
    currentChatId = 'c1';
    repository = FakeMessageRepo();
    store = MessageWindowStore(
      repository: repository,
      currentChatId: () => currentChatId,
      // 用长窗口靠用例显式 flush，提交时机可预期
      flushInterval: const Duration(minutes: 10),
    );
  });

  // 显式提交之外可能还挂着定时器，测试结束前必须取消，否则 flutter_test 会报
  tearDown(() => store.discardPending());

  MessageEntity message(
    String id, {
    String chatId = 'c1',
    String content = '',
  }) => MessageEntity(
    id: id,
    chatId: chatId,
    role: 'assistant',
    content: content,
  );

  group('立即追加/替换', () {
    test('同 id 替换而不是追加', () {
      store.appendOrReplaceNow(message('m1', content: '旧'));
      store.appendOrReplaceNow(message('m1', content: '新'));

      expect(store.messages.value, hasLength(1));
      expect(store.messages.value.single.content, '新');
    });

    test('新 id 追加在尾部', () {
      store.appendOrReplaceNow(message('m1'));
      store.appendOrReplaceNow(message('m2'));

      expect(store.messages.value.map((m) => m.id), ['m1', 'm2']);
    });
  });

  group('流式增量与提交', () {
    test('提交前读不到缓冲里的增量，flush 后才落到窗口', () {
      store.addBuffered(message('m1', content: 'a'), 'c1');
      store.addBuffered(message('m1', content: 'ab'), 'c1');

      expect(store.messages.value, isEmpty, reason: '窗口未到，还在缓冲里');

      store.flush();

      expect(store.messages.value, hasLength(1), reason: '同 id 合并成一条');
      expect(store.messages.value.single.content, 'ab');
    });

    test('缓冲同时只认一个 scope：换 scope 的增量另起一批', () {
      // 核心缓冲在 scope 变化时会重新取快照——旧对话的 pending 不能成为新对话
      // 列表的基础。窗口本身也只属于当前对话，切换由 beginLoad 收尾。
      store.addBuffered(message('a1', chatId: 'c1'), 'c1');
      store.addBuffered(message('b1', chatId: 'c2'), 'c2');

      store.flush();

      expect(store.messages.value.map((m) => m.id), ['b1']);
    });

    test('flushFor 对不匹配的 scope 是 no-op', () {
      store.addBuffered(message('a1', chatId: 'c1'), 'c1');

      store.flushFor('c2');
      expect(store.messages.value, isEmpty, reason: '不是它那批就别提交');

      store.flushFor('c1');
      expect(store.messages.value.map((m) => m.id), ['a1']);
    });

    test('discardPending 丢弃且不提交', () {
      store.addBuffered(message('m1'), 'c1');

      store.discardPending();

      expect(store.messages.value, isEmpty);
    });

    test('applyPage 会丢弃挂起增量：旧增量不得盖回新窗口', () {
      // 这条是这块最容易写反的地方：换窗口时若先 applyPage 再让缓冲按自己的快照
      // 提交，刚铺好的窗口会被整个覆盖回旧列表。
      store.addBuffered(message('stale'), 'c1');

      store.applyPage((messages: [message('fresh')], hasOlder: false));

      expect(store.messages.value.map((m) => m.id), ['fresh']);

      // 之后再 flush 也不该把 stale 写回来
      store.flush();
      expect(store.messages.value.map((m) => m.id), ['fresh']);
    });
  });

  group('加载代次', () {
    test('beginLoad 推进代次并丢弃挂起增量', () {
      final before = store.generation;
      store.addBuffered(message('m1'), 'c1');

      final next = store.beginLoad();

      expect(next, before + 1);
      expect(store.generation, next);
      expect(store.messages.value, isEmpty);
    });

    test('isCurrent：旧代次不算，换了对话也不算', () {
      final generation = store.beginLoad();

      expect(store.isCurrent(generation, 'c1'), isTrue);

      currentChatId = 'c2';
      expect(store.isCurrent(generation, 'c1'), isFalse, reason: '对话已经切走');

      currentChatId = 'c1';
      store.beginLoad();
      expect(store.isCurrent(generation, 'c1'), isFalse, reason: '代次已经过期');
    });
  });

  group('整表操作', () {
    test('clear 清空窗口但不动分页游标以外的状态', () {
      store.applyPage((messages: [message('m1')], hasOlder: true));
      expect(store.hasOlder, isTrue);

      store.clear();

      expect(store.messages.value, isEmpty);
    });

    test('applyPage 无更早消息时 hasOlder 转假', () {
      store.applyPage((messages: [message('m1')], hasOlder: true));
      expect(store.hasOlder, isTrue);

      store.applyPage((messages: [message('m1')], hasOlder: false));

      expect(store.hasOlder, isFalse);
    });

    test('refresh 换一条对话是 no-op', () async {
      repository.total = 3;
      store.applyPage((messages: [message('keep')], hasOlder: false));

      await store.refresh('other');

      expect(store.messages.value.map((m) => m.id), ['keep']);
    });

    test('refresh 重读当前对话的窗口', () async {
      repository.total = 3;

      await store.refresh('c1');

      expect(store.messages.value.map((m) => m.seq), [0, 1, 2]);
      expect(store.hasOlder, isFalse);
    });
  });
}
