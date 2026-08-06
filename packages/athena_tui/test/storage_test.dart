import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/storage/id_allocator.dart';
import 'package:athena_tui/storage/json_array_store.dart';
import 'package:athena_tui/storage/json_file_key_value_store.dart';
import 'package:athena_tui/storage/jsonl_session_repository.dart';
import 'package:athena_tui/storage/session_jsonl_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late IdAllocator idAllocator;
  late JsonlSessionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_test_');
    idAllocator = IdAllocator(File('${tempDir.path}/meta.json'));
    repo = JsonlSessionRepository(
      sessionsDir: Directory('${tempDir.path}/sessions'),
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
      final id1 = await repo.createChat(chat());
      final id2 = await repo.createChat(chat());
      expect(id1, 1);
      expect(id2, 2);
    });

    test('会话文件格式:首行 chat 元数据,消息行带 type', () async {
      final id = await repo.createChat(chat(title: '格式测试'));
      await repo.storeMessage(MessageEntity(
        chatId: id,
        role: 'user',
        content: '你好',
      ));

      final lines =
          await File('${tempDir.path}/sessions/$id.jsonl').readAsLines();
      expect(lines, hasLength(2));
      final chatRow = jsonDecode(lines[0]) as Map<String, dynamic>;
      expect(chatRow['type'], 'chat');
      expect(chatRow['title'], '格式测试');
      final msgRow = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(msgRow['type'], 'message');
      expect(msgRow['content'], '你好');
    });

    test('updateChat 与 recordUsage 并发不丢数据', () async {
      final id = await repo.createChat(chat());

      // 模拟 AgentRunCoordinator 的并发路径:usage 事件写 recordUsage,
      // 同时其他路径整行 updateChat
      await Future.wait([
        repo.recordUsage(id, 100, 50, 20),
        repo.recordUsage(id, 200, 80, 40),
        repo.updateChat(chat(id: id, title: '改标题')),
      ]);

      final updated = await repo.getChatById(id);
      expect(updated, isNotNull);
      expect(updated!.title, '改标题');
      expect(updated.tokenTotal, 300);
      expect(updated.contextTokens, 80);
      expect(updated.cachedTokens, 40);
    });

    test('deleteChat 删除整个会话文件(消息随之删除)', () async {
      final id = await repo.createChat(chat());
      await repo.storeMessage(MessageEntity(
        chatId: id,
        role: 'user',
        content: 'hello',
      ));
      final sessionFile = File('${tempDir.path}/sessions/$id.jsonl');
      expect(await sessionFile.exists(), isTrue);

      await repo.deleteChat(id);
      expect(await sessionFile.exists(), isFalse);
      expect(await repo.getChatsCount(), 0);
      expect(await repo.getMessagesCount(id), 0);
    });

    test('getAllChats 按 pinned + updated_at 排序', () async {
      final now = DateTime.now();
      final old = await repo.createChat(ChatEntity(
        title: '旧',
        modelId: 1,
        sentinelId: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ));
      final recent = await repo.createChat(ChatEntity(
        title: '新',
        modelId: 1,
        sentinelId: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await repo.updateChat(ChatEntity(
        id: old,
        title: '旧',
        modelId: 1,
        sentinelId: 1,
        pinned: true,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ));

      final chats = await repo.getAllChats();
      expect(chats[0].id, old); // 置顶的旧聊天排第一
      expect(chats[1].id, recent);
    });
  });

  group('MessageRepository', () {
    test('消息 id 会话内递增,按会话分文件', () async {
      final chatId = await repo.createChat(chat());
      final id1 = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'user',
        content: 'a',
      ));
      final id2 = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: 'b',
      ));
      expect(id2, id1 + 1);
      final messages = await repo.getMessagesByChatId(chatId);
      expect(messages.map((m) => m.content), ['a', 'b']);
    });

    test('markAsCompacted 排除 compacted 消息', () async {
      final chatId = await repo.createChat(chat());
      final id1 = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'user',
        content: 'a',
      ));
      final id2 = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: 'b',
      ));

      await repo.markAsCompacted({id1});

      final active = await repo.getMessagesByChatId(
        chatId,
        includeCompacted: false,
      );
      expect(active.map((m) => m.id), [id2]);
      final all = await repo.getMessagesByChatId(chatId);
      expect(all.length, 2); // 数据保留,可回溯
      expect(all.first.compacted, isTrue);
    });

    test('流式更新同一消息(id 替换)', () async {
      final chatId = await repo.createChat(chat());
      final id = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: '',
      ));
      for (var i = 1; i <= 5; i++) {
        await repo.updateMessage(MessageEntity(
          id: id,
          chatId: chatId,
          role: 'assistant',
          content: '第 $i 次',
        ));
      }
      final messages = await repo.getMessagesByChatId(chatId);
      expect(messages.length, 1);
      expect(messages.first.content, '第 5 次');
    });

    test('并发 update(整文件重写)与 append 不丢行(单写者锁生效)', () async {
      final chatId = await repo.createChat(chat());
      final id = await repo.storeMessage(MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: 'base',
      ));

      // update 是读-改-整文件重写,append 是追加——若锁不跨调用生效,
      // 重写会吞掉并发追加的行。
      await Future.wait([
        for (var i = 0; i < 5; i++)
          repo.updateMessage(MessageEntity(
            id: id,
            chatId: chatId,
            role: 'assistant',
            content: 'updated$i',
          )),
        for (var i = 0; i < 5; i++)
          repo.storeMessage(MessageEntity(
            chatId: chatId,
            role: 'user',
            content: 'appended$i',
          )),
      ]);

      final messages = await repo.getMessagesByChatId(chatId);
      // 1 条更新(最终内容任意一次)+ 5 条追加,全部保留
      expect(messages.length, 6);
      expect(messages.where((m) => m.role == 'user'), hasLength(5));
      expect(messages.where((m) => m.role == 'assistant'), hasLength(1));
    });
  });

  group('SessionJsonlStore 容错', () {
    test('损坏行跳过不抛异常', () async {
      await Directory('${tempDir.path}/sessions').create(recursive: true);
      final file = File('${tempDir.path}/sessions/1.jsonl');
      await file.writeAsString(
        '{"type":"chat","id":1,"title":"a"}\n'
        'not-json\n'
        '{"type":"message","id":1,"chat_id":1,"role":"user","content":"b"}\n',
      );
      final store = SessionJsonlStore(file: file, idAllocator: idAllocator);
      final rows = await store.readMessageRows();
      expect(rows.length, 1);
      expect(rows.single['content'], 'b');
      expect((await store.readChatRow())?['title'], 'a');
    });

    test('窗口化读取不含会话元数据行', () async {
      final chatId = await repo.createChat(chat(title: '窗口'));
      for (var i = 0; i < 5; i++) {
        await repo.storeMessage(MessageEntity(
          chatId: chatId,
          role: 'user',
          content: '消息 $i',
        ));
      }
      final recent = await repo.loadRecentMessages(chatId, count: 2);
      expect(recent.length, 2); // 首行 chat 记录不占窗口
      expect(recent.map((m) => m.content), ['消息 3', '消息 4']);

      final older = await repo.loadRecentMessages(
        chatId,
        count: 2,
        beforeId: recent.first.id,
      );
      expect(older.map((m) => m.content), ['消息 1', '消息 2']);
    });
  });

  group('JsonArrayStore', () {
    test('损坏文件按空列表容错,不抛异常', () async {
      final store = JsonArrayStore(
        file: File('${tempDir.path}/models.json'),
        idAllocator: idAllocator,
      );
      await store.file.writeAsString('not-json');
      expect(await store.readAll(), isEmpty);
    });

    test('insert 分配自增 id,replaceById/deleteById 生效', () async {
      final store = JsonArrayStore(
        file: File('${tempDir.path}/models.json'),
        idAllocator: idAllocator,
      );
      final id1 = await store.insert({'name': 'a'});
      final id2 = await store.insert({'name': 'b'});
      expect(id2, id1 + 1);
      await store.replaceById(id1, {'name': 'a2'});
      await store.deleteById(id2);
      final rows = await store.readAll();
      expect(rows.single['name'], 'a2');
    });
  });

  group('JsonFileKeyValueStore', () {
    test('并发写入不丢 key(串行锁)', () async {
      final store = JsonFileKeyValueStore(
        file: File('${tempDir.path}/kv.json'),
      );

      // 模拟 WebSearchTool 计数与 AgentSettings 并发写:整文件写路径
      // 无锁时后写覆盖先写,随机丢 key
      await Future.wait([
        for (var i = 0; i < 10; i++) store.setString('str_$i', 'value_$i'),
        for (var i = 0; i < 10; i++) store.setInt('int_$i', i),
      ]);

      final keys = await store.getKeys();
      expect(keys.length, 20);
      for (var i = 0; i < 10; i++) {
        expect(await store.getString('str_$i'), 'value_$i');
        expect(await store.getInt('int_$i'), i);
      }
    });

    test('remove 与 set 并发后状态一致', () async {
      final store = JsonFileKeyValueStore(
        file: File('${tempDir.path}/kv2.json'),
      );
      await store.setString('keep', '1');
      await store.setString('remove_me', '2');

      await Future.wait([
        store.remove('remove_me'),
        store.setString('keep', 'updated'),
      ]);

      expect(await store.getString('keep'), 'updated');
      expect(await store.getString('remove_me'), isNull);
    });
  });

  group('TuiDi 旧数据迁移', () {
    test('旧 chats.jsonl + messages/ 迁移到 sessions/,id 与计数保留', () async {
      final dataDir = Directory('${tempDir.path}/legacy');
      await dataDir.create(recursive: true);
      final now = DateTime.now();
      final chatRow = ChatEntity(
        id: 1,
        title: '旧对话',
        modelId: 1,
        sentinelId: 1,
        createdAt: now,
        updatedAt: now,
      ).toJson();
      final msgRow = MessageEntity(
        id: 1,
        chatId: 1,
        role: 'user',
        content: '你好',
      ).toJson();
      await File('${dataDir.path}/chats.jsonl')
          .writeAsString('${jsonEncode(chatRow)}\n');
      await Directory('${dataDir.path}/messages').create(recursive: true);
      await File('${dataDir.path}/messages/1.jsonl')
          .writeAsString('${jsonEncode(msgRow)}\n');
      // 旧版计数:chats.jsonl 与 messages/{id}.jsonl 各为 key
      await File('${dataDir.path}/meta.json').writeAsString(jsonEncode({
        '${dataDir.path}/chats.jsonl': 1,
        '${dataDir.path}/messages/1.jsonl': 1,
      }));

      final di = TuiDi(dataDirectory: dataDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);

      // 迁移后会话可读,id 原样保留
      final migrated = await di.chatRepo.getChatById(1);
      expect(migrated, isNotNull);
      expect(migrated!.title, '旧对话');
      final messages = await di.messageRepo.getMessagesByChatId(1);
      expect(messages.single.content, '你好');
      // 新文件布局:首行 chat,消息行带 type
      final lines = await File('${dataDir.path}/sessions/1.jsonl')
          .readAsLines();
      expect(jsonDecode(lines[0])['type'], 'chat');
      expect(jsonDecode(lines[1])['type'], 'message');
      // 旧文件已删除,避免重复迁移
      expect(await File('${dataDir.path}/chats.jsonl').exists(), isFalse);
      expect(
        await Directory('${dataDir.path}/messages').exists(),
        isFalse,
      );
      // id 计数迁移:新 chat 从 2 开始;旧会话消息计数保留,新消息 id = 2
      final newChatId = await di.chatRepo.createChat(chat(title: '新对话'));
      expect(newChatId, 2);
      final newMsgId = await di.messageRepo.storeMessage(MessageEntity(
        chatId: newChatId,
        role: 'user',
        content: '新消息',
      ));
      expect(newMsgId, 1); // 新会话消息从 1 开始
      final oldMsgId = await di.messageRepo.storeMessage(MessageEntity(
        chatId: 1,
        role: 'assistant',
        content: '再一条',
      ));
      expect(oldMsgId, 2); // 旧会话消息计数已迁移
    });

    test('旧 models.jsonl / sentinels.jsonl 迁移到 json 数组文件', () async {
      final dataDir = Directory('${tempDir.path}/legacy2');
      await dataDir.create(recursive: true);
      final now = DateTime.now();
      final modelRow = ModelEntity(
        id: 1,
        name: '旧模型',
        modelId: 'deepseek-v4',
        providerId: 1,
        createdAt: now,
        updatedAt: now,
      ).toJson();
      final sentinelRow = SentinelEntity(
        id: 1,
        name: '旧角色',
        prompt: '旧提示词',
      ).toJson();
      await File('${dataDir.path}/models.jsonl')
          .writeAsString('${jsonEncode(modelRow)}\n');
      await File('${dataDir.path}/sentinels.jsonl')
          .writeAsString('${jsonEncode(sentinelRow)}\n');
      await File('${dataDir.path}/meta.json').writeAsString(jsonEncode({
        '${dataDir.path}/models.jsonl': 1,
        '${dataDir.path}/sentinels.jsonl': 1,
      }));

      final di = TuiDi(dataDirectory: dataDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);

      // 迁移的数据原样保留(seed 因计数非 0 跳过)
      expect((await di.modelRepo.getModelById(1))?.name, '旧模型');
      expect((await di.sentinelRepo.getSentinelById(1))?.name, '旧角色');
      // 新文件布局 + 旧文件删除
      expect(await File('${dataDir.path}/models.json').exists(), isTrue);
      expect(await File('${dataDir.path}/sentinels.json').exists(), isTrue);
      expect(await File('${dataDir.path}/models.jsonl').exists(), isFalse);
      expect(await File('${dataDir.path}/sentinels.jsonl').exists(), isFalse);
    });
  });
}
