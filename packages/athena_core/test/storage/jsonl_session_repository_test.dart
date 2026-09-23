import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/session_jsonl_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_opening_preview_');
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

  group('getOpeningAnswerPreview', () {
    test('取首条用户消息之后紧跟的那条回答，不是最新一轮', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', '第一问');
      await addMessage(chatId, 'assistant', '第一答');
      await addMessage(chatId, 'user', '第二问');
      await addMessage(chatId, 'assistant', '第二答');

      expect(
        await storage.sessionRepository.getOpeningAnswerPreview(chatId),
        '第一答',
      );
    });

    test('跨过空内容的占位行，取第一条有正文的回答', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', '第一问');
      // 流式期间 assistant 先落占位行，正文随后才填
      await addMessage(chatId, 'assistant', '');
      await addMessage(chatId, 'assistant', '第一答');

      expect(
        await storage.sessionRepository.getOpeningAnswerPreview(chatId),
        '第一答',
      );
    });

    test('首轮还没有回答时为空串', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', '第一问');
      await addMessage(chatId, 'assistant', '');

      expect(
        await storage.sessionRepository.getOpeningAnswerPreview(chatId),
        '',
      );
    });

    test('空会话为空串', () async {
      final chatId = await createChat();

      expect(
        await storage.sessionRepository.getOpeningAnswerPreview(chatId),
        '',
      );
    });

    test('会话文件不存在时为空串', () async {
      expect(await storage.sessionRepository.getOpeningAnswerPreview(999), '');
    });
  });

  group('loadLeadingMessageRows', () {
    SessionJsonlStore storeOf(int chatId) => SessionJsonlStore(
      file: File(p.join(storage.sessionsDir.path, '$chatId.jsonl')),
      idAllocator: storage.idAllocator,
    );

    test('只读文件头的若干条，跳过首行会话元数据', () async {
      final chatId = await createChat();
      for (var i = 0; i < 5; i++) {
        await addMessage(chatId, 'user', 'q$i');
      }

      final rows = await storeOf(chatId).loadLeadingMessageRows(2);

      expect(rows.length, 2);
      expect(rows.map((row) => row['content']), ['q0', 'q1']);
      expect(
        rows.every((row) => row['type'] == SessionJsonlStore.messageType),
        isTrue,
      );
    });

    test('条数超过文件里已有的消息时返回全部消息', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'q0');

      final rows = await storeOf(chatId).loadLeadingMessageRows(20);

      expect(rows.length, 1);
      expect(rows.single['content'], 'q0');
    });

    test('count 为 0 或文件不存在时为空列表', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'q0');

      expect(await storeOf(chatId).loadLeadingMessageRows(0), isEmpty);
      expect(await storeOf(chatId + 1).loadLeadingMessageRows(5), isEmpty);
    });
  });
}
