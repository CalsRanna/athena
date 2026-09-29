import 'dart:async';

import 'package:athena_core/coordinator/streaming_message_buffer.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:test/test.dart';

void main() {
  final built = <StreamingMessageBuffer>[];
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

  /// 提交记录：每次 commit 记一份快照，用来断言「提交了几次、内容是什么」。
  late List<List<MessageEntity>> commits;
  late List<MessageEntity> current;

  /// 缓冲区建成后以此推进真实定时器。
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  // 不等定时器就结束的用例会把定时器留给下一个用例，而 commit 闭包引用的是
  // 被重新赋值的 commits 变量——泄漏会变成下一个用例的假失败。逐个 discard。
  tearDown(() {
    for (final buffer in built) {
      buffer.discard();
    }
  });

  StreamingMessageBuffer build({Duration? interval}) {
    commits = [];
    current = [];
    final buffer = StreamingMessageBuffer(
      interval: interval ?? const Duration(milliseconds: 10),
      snapshot: () => current,
      commit: (messages) {
        commits.add(List.of(messages));
        current = messages;
      },
    );
    built.add(buffer);
    return buffer;
  }

  group('合并', () {
    test('窗口内的多次增量只提交一次', () async {
      final buffer = build();

      buffer.add(message('m1', content: 'a'));
      buffer.add(message('m1', content: 'ab'));
      buffer.add(message('m1', content: 'abc'));
      expect(commits, isEmpty, reason: '窗口内不得提交');

      await settle();

      expect(commits, hasLength(1));
      expect(current.single.content, 'abc');
    });

    test('提交频率与事件速率解耦：多轮窗口各自提交一次', () async {
      final buffer = build(interval: const Duration(milliseconds: 10));

      buffer.add(message('m1', content: '1'));
      await settle();
      buffer.add(message('m1', content: '2'));
      await settle();

      expect(commits, hasLength(2));
      expect(current.single.content, '2');
    });
  });

  group('追加与更新共用同一批', () {
    test('先追加占位、再更新内容：不会变成两条', () async {
      final buffer = build();

      // 这正是两端注释里警告的顺序：反转的话按 id 替换找不到目标，增量被丢弃。
      buffer.add(message('m1', content: ''));
      buffer.add(message('m1', content: 'streamed'));
      await settle();

      expect(current, hasLength(1));
      expect(current.single.id, 'm1');
      expect(current.single.content, 'streamed');
    });

    test('命中尾部的更新走快速路径，不产生重复', () async {
      final buffer = build();

      buffer.add(message('m1'));
      buffer.add(message('m2'));
      buffer.add(message('m2', content: 'tail'));
      await settle();

      expect(current.map((m) => m.id), ['m1', 'm2']);
      expect(current.last.content, 'tail');
    });

    test('更新不在尾部时按 id 原地替换，不改顺序', () async {
      final buffer = build();

      buffer.add(message('m1'));
      buffer.add(message('m2'));
      buffer.add(message('m1', content: 'updated'));
      await settle();

      expect(current.map((m) => m.id), ['m1', 'm2']);
      expect(current.first.content, 'updated');
    });
  });

  group('scope', () {
    test('换 scope 后重新取快照，旧缓冲不写进新列表', () async {
      final buffer = build();

      buffer.add(message('a1', chatId: 'A'), scope: 'A');
      // 新对话：快照此时还是空的
      buffer.add(message('b1', chatId: 'B'), scope: 'B');
      await settle();

      expect(current.map((m) => m.id), ['b1']);
    });

    test('hasPendingFor 只看本 scope', () {
      final buffer = build();

      buffer.add(message('a1'), scope: 'A');

      expect(buffer.hasPendingFor('A'), isTrue);
      expect(buffer.hasPendingFor('B'), isFalse);
    });
  });

  group('flush 与 discard', () {
    test('flush 立即提交并取消定时器，不重复提交', () async {
      final buffer = build();

      buffer.add(message('m1', content: 'now'));
      buffer.flush();

      expect(commits, hasLength(1));
      expect(current.single.content, 'now');

      await settle();
      expect(commits, hasLength(1), reason: '定时器应已被取消');
    });

    test('无挂起增量时 flush 是 no-op', () {
      final buffer = build();

      buffer.flush();

      expect(commits, isEmpty);
    });

    test('discard 丢弃且不提交，也不留下定时器', () async {
      final buffer = build();

      buffer.add(message('m1'));
      buffer.discard();
      await settle();

      expect(commits, isEmpty);
      expect(current, isEmpty);
    });
  });
}
