import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/storage/jsonl_chat_repository.dart';
import 'package:athena_tui/storage/jsonl_message_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late IdAllocator idAllocator;
  late JsonlChatRepository chatRepo;
  late JsonlMessageRepository messageRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_test_');
    idAllocator = IdAllocator(File('${tempDir.path}/meta.json'));
    chatRepo = JsonlChatRepository(
      file: File('${tempDir.path}/chats.jsonl'),
      messagesDir: Directory('${tempDir.path}/messages'),
      idAllocator: idAllocator,
    );
    messageRepo = JsonlMessageRepository(
      messagesDir: Directory('${tempDir.path}/messages'),
      idAllocator: idAllocator,
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ChatEntity chat({int? id, String title = 'New Chat'}) {
    final now = DateTime.now();
    return ChatEntity(
      id: id,
      title: title,
      modelId: 1,
      sentinelId: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('ChatRepository', () {
    test('createChat 分配自增 id', () async {
      final id1 = await chatRepo.createChat(chat());
      final id2 = await chatRepo.createChat(chat());
      expect(id1, 1);
      expect(id2, 2);
    });

    test('updateChat 与 recordUsage 并发不丢数据', () async {
      final id = await chatRepo.createChat(chat());

      // 模拟 AgentRunCoordinator 的并发路径:usage 事件写 recordUsage,
      // 同时其他路径整行 updateChat
      await Future.wait([
        chatRepo.recordUsage(id, 100, 50, 20),
        chatRepo.recordUsage(id, 200, 80, 40),
        chatRepo.updateChat(chat(id: id, title: '改标题')),
      ]);

      final updated = await chatRepo.getChatById(id);
      expect(updated, isNotNull);
      expect(updated!.title, '改标题');
      expect(updated.tokenTotal, 300);
      expect(updated.contextTokens, 80);
      expect(updated.cachedTokens, 40);
    });

    test('deleteChat 级联删除消息文件', () async {
      final id = await chatRepo.createChat(chat());
      await messageRepo.storeMessage(MessageEntity(
        chatId: id,
        role: 'user',
        content: 'hello',
      ));
      final msgFile = File('${tempDir.path}/messages/$id.jsonl');
      expect(await msgFile.exists(), isTrue);

      await chatRepo.deleteChat(id);
      expect(await msgFile.exists(), isFalse);
      expect(await chatRepo.getChatsCount(), 0);
    });

    test('getAllChats 按 pinned + updated_at 排序', () async {
      final now = DateTime.now();
      final old = await chatRepo.createChat(ChatEntity(
        title: '旧',
        modelId: 1,
        sentinelId: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ));
      final recent = await chatRepo.createChat(ChatEntity(
        title: '新',
        modelId: 1,
        sentinelId: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await chatRepo.updateChat(ChatEntity(
        id: old,
        title: '旧',
        modelId: 1,
        sentinelId: 1,
        pinned: true,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ));

      final chats = await chatRepo.getAllChats();
      expect(chats[0].id, old); // 置顶的旧聊天排第一
      expect(chats[1].id, recent);
    });
  });

  group('MessageRepository', () {
    test('消息 id 全局递增,按 chat 分文件', () async {
      final chatId = await chatRepo.createChat(chat());
      final id1 = await messageRepo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'user',
        content: 'a',
      ));
      final id2 = await messageRepo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: 'b',
      ));
      expect(id2, id1 + 1);
      final messages = await messageRepo.getMessagesByChatId(chatId);
      expect(messages.map((m) => m.content), ['a', 'b']);
    });

    test('markAsCompacted 排除 compacted 消息', () async {
      final chatId = await chatRepo.createChat(chat());
      final id1 = await messageRepo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'user',
        content: 'a',
      ));
      final id2 = await messageRepo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: 'b',
      ));

      await messageRepo.markAsCompacted({id1});

      final active = await messageRepo.getMessagesByChatId(
        chatId,
        includeCompacted: false,
      );
      expect(active.map((m) => m.id), [id2]);
      final all = await messageRepo.getMessagesByChatId(chatId);
      expect(all.length, 2); // 数据保留,可回溯
      expect(all.first.compacted, isTrue);
    });

    test('流式更新同一消息(id 替换)', () async {
      final chatId = await chatRepo.createChat(chat());
      final id = await messageRepo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: '',
      ));
      for (var i = 1; i <= 5; i++) {
        await messageRepo.updateMessage(MessageEntity(
          id: id,
          chatId: chatId,
          role: 'assistant',
          content: '第 $i 次',
        ));
      }
      final messages = await messageRepo.getMessagesByChatId(chatId);
      expect(messages.length, 1);
      expect(messages.first.content, '第 5 次');
    });
  });

  group('JsonlFileStore 容错', () {
    test('损坏行跳过不抛异常', () async {
      final file = File('${tempDir.path}/broken.jsonl');
      await file.writeAsString('{"id": 1, "name": "a"}\nnot-json\n{"id": 2, "name": "b"}\n');
      final store = JsonlFileStore(file: file, idAllocator: idAllocator);
      final rows = await store.readAll();
      expect(rows.length, 2);
    });
  });
}
