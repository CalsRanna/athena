import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/approval_mode.dart';
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

  Future<String> createChat() => storage.sessionRepository.createChat(
    ChatEntity(
      title: 't',
      modelId: '1',
      sentinelId: '1',
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> addMessage(String chatId, String role, String content) {
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
      expect(await storage.sessionRepository.getTurnStartIds('999'), isEmpty);
    });
  });

  group('loadRecentRows', () {
    SessionJsonlStore storeOf(String chatId) => SessionJsonlStore(
      file: File(p.join(storage.sessionsDir.path, '$chatId.jsonl')),
      locks: storage.locks,
      idGenerator: storage.idGenerator,
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
        beforeSeq: latest.first['seq'] as int,
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
        beforeSeq: newest.single['seq'] as int,
      );
      expect(middle.single['content'], huge);
      final oldest = await store.loadRecentRows(
        1,
        beforeSeq: middle.single['seq'] as int,
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
        '${chatId}1',
        pageSize: 5,
      );

      expect(empty.messages, isEmpty);
      expect(empty.hasOlder, isFalse);
      expect(missing.messages, isEmpty);
      expect(missing.hasOlder, isFalse);
    });
  });

  // 批量删除与标记仅作用于指定会话，不遍历或修改其他会话文件。
  group('deleteMessages / markAsCompacted 按会话隔离', () {
    /// 建 [count] 条消息，返回 (chatId, ids)。
    Future<(String, List<String>)> chatWith(int count, String prefix) async {
      final chatId = await createChat();
      final ids = <String>[];
      for (var i = 0; i < count; i++) {
        ids.add(
          (await storage.sessionRepository.storeMessage(
            MessageEntity(chatId: chatId, role: 'user', content: '$prefix$i'),
          )).id!,
        );
      }
      return (chatId, ids);
    }

    Future<List<(String, String)>> rows(String chatId) async {
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

    test('只删目标会话，另一个会话原样保留', () async {
      final (a, aIds) = await chatWith(3, 'A');
      final (b, bIds) = await chatWith(3, 'B');
      expect(aIds.toSet().intersection(bIds.toSet()), isEmpty);

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

    test('markAsCompacted 只标目标会话，另一个会话不受影响', () async {
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

  group('审批档位随会话隔离', () {
    test('改一条会话的档位，另一条不受影响', () async {
      final a = await storage.sessionRepository.createChat(
        ChatEntity(
          title: 'a',
          modelId: '1',
          sentinelId: '1',
          approvalMode: ApprovalMode.manual,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final b = await storage.sessionRepository.createChat(
        ChatEntity(
          title: 'b',
          modelId: '1',
          sentinelId: '1',
          approvalMode: ApprovalMode.bypass,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final updated = await storage.sessionRepository.getChatById(a);
      await storage.sessionRepository.updateChat(
        updated!.copyWith(approvalMode: ApprovalMode.aiReview),
      );

      expect(
        (await storage.sessionRepository.getChatById(a))!.approvalMode,
        ApprovalMode.aiReview,
      );
      expect(
        (await storage.sessionRepository.getChatById(b))!.approvalMode,
        ApprovalMode.bypass,
        reason: '档位挂在会话上，改 A 不该动到 B',
      );
    });

    test('早期会话文件没有 approval_mode 键时回落默认档', () async {
      final chatId = await createChat();
      // 直接改文件首行，模拟会话级档位引入之前落库的会话
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      final row = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(row.remove('approval_mode'), isNotNull);
      lines[0] = jsonEncode(row);
      await file.writeAsString('${lines.join('\n')}\n');

      expect(
        (await storage.sessionRepository.getChatById(chatId))!.approvalMode,
        ApprovalMode.defaultMode,
      );
    });

    test('写入后重新读取保持一致', () async {
      final chatId = await storage.sessionRepository.createChat(
        ChatEntity(
          title: 't',
          modelId: '1',
          sentinelId: '1',
          approvalMode: ApprovalMode.bypass,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(
        (await storage.sessionRepository.getChatById(chatId))!.approvalMode,
        ApprovalMode.bypass,
      );
    });
  });

  // replaceMessage 只重编码被改的那一行，其余行按原始字节拼回。这里锁住
  // 字节保留带来的可观察差异与几条容易踩坏的边界。
  group('replaceMessage 只重写目标行', () {
    Future<String> createChatWith(List<String> contents) async {
      final chatId = await createChat();
      for (final content in contents) {
        await addMessage(chatId, 'user', content);
      }
      return chatId;
    }

    File fileOf(String chatId) =>
        File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));

    test('未命中的行逐字节保留（含非规范化空白写法）', () async {
      final chatId = await createChatWith(['a', 'b', 'c']);
      final file = fileOf(chatId);
      final before = await file.readAsLines();
      // 中间行加多余空格（保持 JSON 合法、字段完整），验证它被逐字节保留
      final raw = before[2].replaceFirst('"content":"b"', '"content" :   "b"');
      expect(raw, isNot(before[2]), reason: '扰动必须真的落到这一行上');
      final handcrafted = [...before]..[2] = raw;
      await file.writeAsString('${handcrafted.join('\n')}\n');

      await storage.sessionRepository.updateMessage(
        (await storage.sessionRepository.getMessageById(
          chatId,
          (jsonDecode(handcrafted[1]) as Map<String, dynamic>)['id'] as String,
        ))!.copyWith(content: 'edited'),
      );

      final after = await file.readAsLines();
      expect(after[2], raw, reason: '未改动行的原始字节必须原样留下');
      expect(after.length, handcrafted.length);
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['edited', 'b', 'c'],
      );
    });

    test('id 只出现在别行的 content 里时不会误改那一行', () async {
      final chatId = await createChatWith(['a', 'b']);
      final ids = (await storage.sessionRepository.getMessagesByChatId(
        chatId,
      )).map((m) => m.id!).toList();
      // 让第一条的 content 里出现第二条的 id，且排在文件更前面
      final first = await storage.sessionRepository.getMessageById(
        chatId,
        ids[0],
      );
      await storage.sessionRepository.updateMessage(
        first!.copyWith(content: 'mentions ${ids[1]} inline'),
      );

      await storage.sessionRepository.updateMessage(
        (await storage.sessionRepository.getMessageById(
          chatId,
          ids[1],
        ))!.copyWith(content: 'target'),
      );

      final messages = await storage.sessionRepository.getMessagesByChatId(
        chatId,
      );
      expect(messages[0].content, 'mentions ${ids[1]} inline');
      expect(messages[1].content, 'target');
    });

    test('读不出来的损坏行不被静默丢弃', () async {
      final chatId = await createChatWith(['a', 'b']);
      final file = fileOf(chatId);
      final lines = await file.readAsLines();
      // 在中间插入一行坏 JSON（模拟写到一半断电）
      final broken = [...lines]..insert(2, '{not json');
      await file.writeAsString('${broken.join('\n')}\n');

      final target = await storage.sessionRepository.getMessageById(
        chatId,
        (jsonDecode(lines[1]) as Map<String, dynamic>)['id'] as String,
      );
      await storage.sessionRepository.updateMessage(
        target!.copyWith(content: 'edited'),
      );

      final after = await file.readAsLines();
      expect(
        after.contains('{not json'),
        isTrue,
        reason: '改一行不该顺手把损坏行抹掉——丢数据不是这里的决定',
      );
      // 损坏行读的时候照旧被跳过
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['edited', 'b'],
      );
    });

    test('保留原 seq，传入别的 seq 不生效', () async {
      final chatId = await createChatWith(['a', 'b']);
      final id = (await storage.sessionRepository.getMessagesByChatId(
        chatId,
      ))[0].id!;
      await storage.sessionRepository.updateMessage(
        (await storage.sessionRepository.getMessageById(
          chatId,
          id,
        ))!.copyWith(content: 'edited', seq: 999),
      );
      expect(
        (await storage.sessionRepository.getMessageById(chatId, id))!.seq,
        1,
      );
    });

    test('文件末尾缺换行时改末行仍写出完整行', () async {
      final chatId = await createChatWith(['a', 'b']);
      final file = fileOf(chatId);
      var text = await file.readAsString();
      if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
      await file.writeAsString(text);

      final id = (await storage.sessionRepository.getMessagesByChatId(
        chatId,
      ))[1].id!;
      await storage.sessionRepository.updateMessage(
        (await storage.sessionRepository.getMessageById(
          chatId,
          id,
        ))!.copyWith(content: 'edited'),
      );

      expect((await file.readAsString()).endsWith('\n'), isTrue);
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['a', 'edited'],
      );
    });

    test('目标 id 不存在时抛错且文件不变', () async {
      final chatId = await createChatWith(['a']);
      final file = fileOf(chatId);
      final before = await file.readAsString();
      await expectLater(
        storage.sessionRepository.updateMessage(
          MessageEntity(
            chatId: chatId,
            role: 'user',
            content: 'x',
          ).copyWith(id: 'no-such-id'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await file.readAsString(), before);
    });
  });

  // updateChatRow 只重写元数据那一行（recordUsage 每个工具迭代都会走）。
  group('updateChatRow 只重写元数据行', () {
    test('改 usage 后消息行逐字节保留', () async {
      final chatId = await createChat();
      for (final content in ['a', 'b']) {
        await addMessage(chatId, 'user', content);
      }
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      // 给消息行加多余空格，验证它们不会被重编码
      final raw = lines[2].replaceFirst('"content":"b"', '"content" :  "b"');
      expect(raw, isNot(lines[2]));
      final handcrafted = [...lines]..[2] = raw;
      await file.writeAsString('${handcrafted.join('\n')}\n');

      await storage.sessionRepository.recordUsage(chatId, 123, 45);

      final after = await file.readAsLines();
      expect(after[2], raw, reason: '消息行的原始字节必须原样留下');
      expect(after.length, handcrafted.length);
      final chat = await storage.sessionRepository.getChatById(chatId);
      expect(chat!.contextTokens, 123);
      expect(chat.cachedTokens, 45);
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['a', 'b'],
      );
    });

    test('元数据行不在首行时也能定位并重写', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'a');
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      // 把元数据行从首行挪到最后，模拟非规范布局
      final moved = [...lines.sublist(1), lines.first];
      await file.writeAsString('${moved.join('\n')}\n');
      final messageLine = moved.first;

      await storage.sessionRepository.recordUsage(chatId, 7, 8);

      final after = await file.readAsLines();
      expect(after.first, messageLine, reason: '消息行仍在最前且逐字节不变');
      expect(
        (await storage.sessionRepository.getChatById(chatId))!.contextTokens,
        7,
      );
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['a'],
      );
    });

    test('没有元数据行时返回空且不改文件', () async {
      final chatId = await createChat();
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      // 只留消息行，去掉元数据
      final lines = await file.readAsLines();
      await file.writeAsString('${lines.sublist(1).join('\n')}\n');
      final before = await file.readAsString();

      await storage.sessionRepository.recordUsage(chatId, 1, 1);
      expect(await file.readAsString(), before);
    });
  });

  // readChatRow 走「只读首行」快速路径（getChatById 在每次 usage 后都被调用）。
  group('readChatRow 首行快速路径', () {
    test('元数据不在首行时回退整文件扫描仍能读到', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'a');
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      // 元数据挪到最后
      await file.writeAsString(
        '${[...lines.sublist(1), lines.first].join('\n')}\n',
      );

      final chat = await storage.sessionRepository.getChatById(chatId);
      expect(chat, isNotNull, reason: '首行不是元数据时必须回落整文件扫描');
      expect(chat!.id, chatId);
    });

    test('首行损坏时回退后仍能读到别处的元数据行', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'a');
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      // 首行换成坏 JSON，元数据挤到第二行
      await file.writeAsString(
        '{broken\n${lines.first}\n${lines.sublist(1).join('\n')}\n',
      );

      final chat = await storage.sessionRepository.getChatById(chatId);
      expect(chat, isNotNull);
      expect(chat!.id, chatId);
      // 消息仍能正常读出（坏行被跳过）
      expect(
        (await storage.sessionRepository.getMessagesByChatId(
          chatId,
        )).map((m) => m.content),
        ['a'],
      );
    });

    test('首行超过探测窗口时回退整文件扫描', () async {
      final chatId = await createChat();
      await addMessage(chatId, 'user', 'a');
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      final lines = await file.readAsLines();
      // 首行塞一个 100KB 的填充键（超过 64KB 探测窗口），元数据仍在其中
      final row = jsonDecode(lines.first) as Map<String, dynamic>;
      row['pad'] = 'x' * 100000;
      await file.writeAsString(
        '${[jsonEncode(row), ...lines.sublist(1)].join('\n')}\n',
      );

      final chat = await storage.sessionRepository.getChatById(chatId);
      expect(chat, isNotNull, reason: '探测窗口不够时必须回落');
      expect(chat!.id, chatId);
    });

    test('空文件与只有消息行的文件返回 null', () async {
      final chatId = await createChat();
      final file = File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));
      await file.writeAsString('');
      expect(await storage.sessionRepository.getChatById(chatId), isNull);

      await addMessage(chatId, 'user', 'a');
      final lines = await file.readAsLines();
      await file.writeAsString('${lines.sublist(1).join('\n')}\n');
      expect(await storage.sessionRepository.getChatById(chatId), isNull);
    });
  });
}
