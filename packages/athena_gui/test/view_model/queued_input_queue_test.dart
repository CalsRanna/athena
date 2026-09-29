import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/view_model/queued_input_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// 待发输入队列的契约。
///
/// 它此前长在 ChatViewModel 里，只能通过 run 流程间接覆盖。切出来之后这里直接
/// 测排队语义——尤其「按对象标识去重与移除」这条：按内容去重会把用户真发两次的
/// 同一句话吞掉一条。
void main() {
  ChatEntity chat(String id) => ChatEntity(
    id: id,
    title: id,
    modelId: 'm',
    sentinelId: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  MessageEntity message(String id, String chatId) =>
      MessageEntity(id: id, chatId: chatId, role: 'user', content: id);

  QueuedChatInput input(String id, String chatId) =>
      QueuedChatInput(message(id, chatId), chat(chatId), false);

  group('入队与取队首', () {
    test('按入队顺序先进先出', () {
      final queue = QueuedInputQueue();

      queue.enqueue(input('a', 'c1'));
      queue.enqueue(input('b', 'c1'));

      expect(queue.all.map((i) => i.message.id), ['a', 'b']);
      expect(queue.nextFor('c1')?.message.id, 'a');
    });

    test('nextFor 只在自己会话里取最早的', () {
      final queue = QueuedInputQueue();
      queue.enqueue(input('a', 'c1'));
      queue.enqueue(input('x', 'c2'));
      queue.enqueue(input('b', 'c1'));

      expect(queue.nextFor('c1')?.message.id, 'a');
      expect(queue.nextFor('c2')?.message.id, 'x');
      expect(queue.nextFor('c3'), isNull);
    });

    test('messagesFor 只给当前会话，保序', () {
      final queue = QueuedInputQueue();
      queue.enqueue(input('a', 'c1'));
      queue.enqueue(input('x', 'c2'));
      queue.enqueue(input('b', 'c1'));

      expect(queue.messagesFor('c1').map((m) => m.id), ['a', 'b']);
      expect(queue.messagesFor('c2').map((m) => m.id), ['x']);
      expect(queue.messagesFor(null), isEmpty);
    });
  });

  group('按对象标识去重与移除', () {
    test('同一个对象排两次只留一条', () {
      final queue = QueuedInputQueue();
      final same = input('a', 'c1');

      queue.enqueue(same);
      queue.enqueue(same);

      expect(queue.all, hasLength(1));
    });

    test('内容相同的两个对象是两条输入', () {
      // 用户确实发了两次同一句话，不能被吞掉一条。
      final queue = QueuedInputQueue();

      queue.enqueue(input('a', 'c1'));
      queue.enqueue(input('a', 'c1'));

      expect(queue.all, hasLength(2));
    });

    test('remove 按标识移除，不在队里时是 no-op', () {
      final queue = QueuedInputQueue();
      final first = input('a', 'c1');
      final second = input('b', 'c1');
      queue.enqueue(first);
      queue.enqueue(second);

      queue.remove(first);
      expect(queue.all.map((i) => i.message.id), ['b']);

      queue.remove(input('a', 'c1'));
      expect(queue.all, hasLength(1), reason: '不同对象不该误删');
    });
  });

  group('清理', () {
    test('discardChats 只丢指定会话的排队项', () {
      final queue = QueuedInputQueue();
      queue.enqueue(input('a', 'c1'));
      queue.enqueue(input('x', 'c2'));
      queue.enqueue(input('b', 'c1'));

      queue.discardChats({'c1'});

      expect(queue.all.map((i) => i.message.id), ['x']);
    });

    test('clear 清空，isEmpty 跟随', () {
      final queue = QueuedInputQueue();
      expect(queue.isEmpty, isTrue);

      queue.enqueue(input('a', 'c1'));
      expect(queue.isEmpty, isFalse);

      queue.clear();
      expect(queue.isEmpty, isTrue);
      expect(queue.all, isEmpty);
    });
  });
}
