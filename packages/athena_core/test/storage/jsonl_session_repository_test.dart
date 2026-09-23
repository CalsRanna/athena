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
}
