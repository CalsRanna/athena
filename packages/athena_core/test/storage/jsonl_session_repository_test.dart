import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/session_jsonl_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_jsonl_session_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
  });

  tearDown(() => tmp.delete(recursive: true));

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Future<int> createChat() => storage.sessionRepository.createChat(
    ChatEntity(
      title: 't',
      modelId: 1,
      sentinelId: 1,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> addMessage(int chatId, String role, String content) {
    return storage.sessionRepository.storeMessage(
      MessageEntity(chatId: chatId, role: role, content: content),
    );
  }

  group('getTurnStartIds', () {
    test('按行序返回每轮的起点（只有 user 行），含未加载的历史', () async {
      final chatId = await createChat();
      // 首轮带两条 assistant（流式占位 + 正文），仍只算一轮
      await addMessage(chatId, 'user', '第一问');
      await addMessage(chatId, 'assistant', '');
      await addMessage(chatId, 'assistant', '第一答');
      await addMessage(chatId, 'user', '第二问');
      await addMessage(chatId, 'assistant', '第二答');
      await addMessage(chatId, 'user', '第三问');

      final ids = await storage.sessionRepository.getTurnStartIds(chatId);
      final all = await storage.sessionRepository.getMessagesByChatId(chatId);
      final userIds = [
        for (final message in all)
          if (message.role == 'user') message.id!,
      ];

      // 与文件里的 user 行一一对应，且保持行序
      expect(ids, orderedEquals(userIds));
      expect(userIds.length, 3);
    });

    test('空会话与不存在的会话返回空列表', () async {
      final chatId = await createChat();

      expect(await storage.sessionRepository.getTurnStartIds(chatId), isEmpty);
      expect(await storage.sessionRepository.getTurnStartIds(999), isEmpty);
    });
  });

  group('loadRecentRows', () {
    SessionJsonlStore storeOf(int chatId) => SessionJsonlStore(
      file: File(p.join(storage.sessionsDir.path, '$chatId.jsonl')),
      idAllocator: storage.idAllocator,
    );

    test('从尾部往回取给个条数，结果按 id 升序', () async {
      final chatId = await createChat();
      for (var i = 0; i < 8; i++) {
        await addMessage(chatId, 'user', 'q$i');
      }
      final store = storeOf(chatId);

      final latest = await store.loadRecentRows(3);
      expect(latest.map((row) => row['content']), ['q5', 'q6', 'q7']);

      // 游标：取 id 小于它的最近几条
      final older = await store.loadRecentRows(
        3,
        beforeId: latest.first['id'] as int,
      );
      expect(older.map((row) => row['content']), ['q2', 'q3', 'q4']);
    });

    test('超长行跨多个读块也能切全，相邻行不受影响', () async {
      final chatId = await createChat();
      // 比单次读块（64KB）大得多：块边界会落在这一行内部
      final huge = 'H' * 200000;
      await addMessage(chatId, 'user', '前一条');
      await addMessage(chatId, 'assistant', huge);
      await addMessage(chatId, 'user', '后一条');

      final rows = await storeOf(chatId).loadRecentRows(3);

      expect(rows.map((row) => row['content']), ['前一条', huge, '后一条']);
    });

    test('游标之后的超长行被跳过，且能继续向前取到更早的行', () async {
      final chatId = await createChat();
      final huge = 'H' * 200000;
      await addMessage(chatId, 'user', 'q0');
      await addMessage(chatId, 'assistant', huge);
      await addMessage(chatId, 'user', 'q2');
      final store = storeOf(chatId);

      final newest = await store.loadRecentRows(1);
      expect(newest.single['content'], 'q2');
      // 这一页必须扫过那条超长行才对（旧实现会在这里反复复制半行）
      final middle = await store.loadRecentRows(
        1,
        beforeId: newest.single['id'] as int,
      );
      expect(middle.single['content'], huge);
      final oldest = await store.loadRecentRows(
        1,
        beforeId: middle.single['id'] as int,
      );
      expect(oldest.single['content'], 'q0');
    });
  });

  group('loadInitialMessages', () {
    test('够小的会话一次给整段，hasOlder 为 false', () async {
      final chatId = await createChat();
      for (var i = 0; i < 5; i++) {
        await addMessage(chatId, 'user', 'q$i');
      }

      final window = await storage.sessionRepository.loadInitialMessages(
        chatId,
        pageSize: 2,
      );

      expect(window.messages.map((m) => m.content), [
        'q0',
        'q1',
        'q2',
        'q3',
        'q4',
      ]);
      expect(window.hasOlder, isFalse);
    });

    test('超过阈值的会话仍只给尾部一页，hasOlder 为 true', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'q0');
      // 一条行就把文件撑过阈值：整读的分流只看字节数
      final huge = 'x' * JsonlSessionRepository.wholeSessionMaxBytes;
      await addMessage(chatId, 'assistant', huge);

      final window = await storage.sessionRepository.loadInitialMessages(
        chatId,
        pageSize: 1,
      );

      expect(window.messages.single.content, huge);
      expect(window.hasOlder, isTrue);
    });

    test('空会话与不存在的会话给空窗口', () async {
      final chatId = await createChat();

      final empty = await storage.sessionRepository.loadInitialMessages(
        chatId,
        pageSize: 5,
      );
      final missing = await storage.sessionRepository.loadInitialMessages(
        chatId + 1,
        pageSize: 5,
      );

      expect(empty.messages, isEmpty);
      expect(empty.hasOlder, isFalse);
      expect(missing.messages, isEmpty);
      expect(missing.hasOlder, isFalse);
    });
  });

  // 消息 id 是每会话独立计数（都从 1 开始），所以「按 id 跨会话查找」的删除与
  // 标记一定会命中别的会话：目标会话删不掉、另一个对话静默丢消息。
  group('deleteMessages / markAsCompacted 按会话隔离', () {
    /// 建 [count] 条消息，返回 (chatId, ids)。
    Future<(int, List<int>)> chatWith(int count, String prefix) async {
      final chatId = await createChat();
      final ids = <int>[];
      for (var i = 0; i < count; i++) {
        ids.add(
          await storage.sessionRepository.storeMessage(
            MessageEntity(chatId: chatId, role: 'user', content: '$prefix$i'),
          ),
        );
      }
      return (chatId, ids);
    }

    Future<List<(int, String)>> rows(int chatId) async {
      final messages = await storage.sessionRepository.getMessagesByChatId(
        chatId,
      );
      return [for (final m in messages) (m.id!, m.content)];
    }

    Future<List<String>> fileOrder() async {
      final names = <String>[];
      await for (final entity in storage.sessionsDir.list()) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          names.add(entity.uri.pathSegments.last);
        }
      }
      return names;
    }

    test('两个会话同 id 时只删目标会话，另一个会话原样保留', () async {
      final (a, aIds) = await chatWith(3, 'A');
      final (b, bIds) = await chatWith(3, 'B');
      expect(aIds, bIds); // 前提：id 跨会话重名

      // 按 id 跨会话查找命中的是目录序里第一个含该 id 的文件（`_sessionFiles`
      // 走的就是目录序），所以删除必须挑「排在后面」的会话：只有这样才能
      // 暴露"删到先序会话、目标会话没删掉"。
      final order = await fileOrder();
      final aFirst = order.indexOf('$a.jsonl') < order.indexOf('$b.jsonl');
      final target = aFirst ? b : a;
      final victim = aFirst ? a : b;
      final targetIds = aFirst ? bIds : aIds;
      final victimIds = aFirst ? aIds : bIds;
      final targetPrefix = aFirst ? 'B' : 'A';
      final victimPrefix = aFirst ? 'A' : 'B';

      await storage.sessionRepository.deleteMessages(target, {
        targetIds[1],
        targetIds[2],
      });

      expect(await rows(target), [(targetIds[0], '${targetPrefix}0')]);
      expect(await rows(victim), [
        (victimIds[0], '${victimPrefix}0'),
        (victimIds[1], '${victimPrefix}1'),
        (victimIds[2], '${victimPrefix}2'),
      ]);
    });

    test('ids 为空时不改动任何会话', () async {
      final (a, aIds) = await chatWith(2, 'A');
      final (b, bIds) = await chatWith(2, 'B');

      await storage.sessionRepository.deleteMessages(a, const {});

      expect((await rows(a)).map((r) => r.$1), aIds);
      expect((await rows(b)).map((r) => r.$1), bIds);
    });

    test('markAsCompacted 只标目标会话，另一个会话的同 id 行不受影响', () async {
      final (a, aIds) = await chatWith(3, 'A');
      final (b, bIds) = await chatWith(3, 'B');

      await storage.sessionRepository.markAsCompacted(b, {bIds[0], bIds[1]});

      final allA = await storage.sessionRepository.getMessagesByChatId(a);
      final keptB = await storage.sessionRepository.getMessagesByChatId(
        b,
        includeCompacted: false,
      );
      expect(allA.map((m) => m.compacted), [false, false, false]);
      expect(keptB.map((m) => m.id), [bIds[2]]);
      expect(aIds.length, 3);
    });
  });
}
