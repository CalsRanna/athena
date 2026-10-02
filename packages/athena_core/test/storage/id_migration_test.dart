import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/storage_id_migration.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _ReversedIds extends IdGenerator {
  int _next = 100;
  @override
  String next() => 'id-${_next--}';
}

void main() {
  late Directory temp;
  late FileStorage storage;
  final uuid7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_ids_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
  });
  tearDown(() => temp.delete(recursive: true));

  Future<File> write(String name, Object data) async {
    final file = File(p.join(storage.root.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsString(data is String ? data : jsonEncode(data));
    return file;
  }

  ChatEntity chat(String title) => ChatEntity(
    title: title,
    modelId: 'model',
    sentinelId: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('新 ID 是 UUIDv7，跨实例生成无需计数文件', () async {
    final ids = {for (var i = 0; i < 10000; i++) const IdGenerator().next()};
    expect(ids, hasLength(10000));
    expect(ids, everyElement(matches(uuid7)));
    final a = await storage.sessionRepository.createChat(chat('a'));
    final b = await FileStorage(
      root: storage.root,
    ).sessionRepository.createChat(chat('b'));
    expect(a, isNot(b));
    expect(await storage.metaFile.exists(), isFalse);
  });

  test('消息 UUID 逆序生成时，分页、更新、压缩仍按 seq', () async {
    final repo = JsonlSessionRepository(
      sessionsDir: storage.sessionsDir,
      locks: storage.locks,
      idGenerator: _ReversedIds(),
    );
    final chatId = await repo.createChat(chat('ordered'));
    final messages = <MessageEntity>[];
    for (var i = 0; i < 5; i++) {
      messages.add(
        await repo.storeMessage(
          MessageEntity(chatId: chatId, role: 'user', content: '$i'),
        ),
      );
    }
    expect(messages.map((m) => m.seq), [1, 2, 3, 4, 5]);
    final page = await repo.loadRecentMessages(chatId, count: 2, beforeSeq: 5);
    expect(page.map((m) => m.content), ['2', '3']);
    await repo.updateMessage(messages[1].copyWith(content: 'edited', seq: 999));
    expect((await repo.getMessageById(chatId, messages[1].id!))!.seq, 2);
    final summary = ConversationSummary.create(
      chatId: chatId,
      content: 'summary',
      coveredRecords: messages.take(3).toList(),
    ).copyWith(id: 'summary', seq: 6);
    final history = ConversationSummary.activeHistory([...messages, summary]);
    expect(history.map((m) => m.content), ['summary', '3', '4']);
    expect(
      ConversationSummary.coveredIds(summary),
      messages.take(3).map((m) => m.id).toSet(),
    );
  });

  test('两个进程追加同一会话，seq 连续且 ID 不重复', () async {
    final chatId = await storage.sessionRepository.createChat(chat('shared'));
    final worker = File(p.join(temp.path, 'worker.dart'));
    await worker.writeAsString('''
import 'dart:io';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/entity/message_entity.dart';
Future<void> main(List<String> args) async {
  final repo = FileStorage(root: Directory(args[0])).sessionRepository;
  for (var i = 0; i < 15; i++) {
    await repo.storeMessage(MessageEntity(chatId: args[1], role: 'user', content: args[2]));
  }
}
''');
    final results = await Future.wait([
      for (final name in ['gui', 'tui'])
        Process.run(Platform.resolvedExecutable, [
          '--packages=${p.absolute('.dart_tool/package_config.json')}',
          worker.path,
          storage.root.path,
          chatId,
          name,
        ]),
    ]);
    for (final result in results) {
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    final messages = await storage.sessionRepository.getMessagesByChatId(
      chatId,
    );
    expect(messages.map((m) => m.seq), List.generate(30, (i) => i + 1));
    expect(messages.map((m) => m.id).toSet(), hasLength(30));
    expect(messages.where((m) => m.content == 'gui'), hasLength(15));
    expect(messages.where((m) => m.content == 'tui'), hasLength(15));
  });

  test('整数迁移覆盖会话、摘要、协议状态、经验和角色快照，重启不重复迁移', () async {
    await write(
      'setting.yaml',
      'model: model-name\nproviders:\n  - id: 1\n    name: Provider\n    apiKey: "test-key"\n',
    );
    await write('models.json', [
      {'id': 3, 'provider_id': 1, 'model_id': 'model-name'},
    ]);
    await write('sentinels.json', [
      {'id': 2, 'name': 'Reviewer'},
    ]);
    await write('meta.json', {'/old/path/sessions': 99});
    final originalState = {
      'provider_id': 1,
      'signature': 'untouched',
      'message_hash': 'hash',
    };
    Map<String, dynamic> oldChat(int id, int sentinel) => {
      'type': 'chat',
      'id': id,
      'model_id': 3,
      'sentinel_id': sentinel,
      'title': 'chat-$id',
      'created_at': 1,
      'updated_at': 2,
    };
    Map<String, dynamic> oldMessage(int chatId, int id) => {
      'type': 'message',
      'id': id,
      'chat_id': chatId,
      'role': 'user',
      'content': 'm$id',
    };
    final rows = [
      oldChat(10, 2),
      {
        ...oldMessage(10, 1),
        for (final key in [
          'responses_state',
          'messages_state',
          'chat_completions_state',
        ])
          key: jsonEncode(originalState),
      },
      oldMessage(10, 2),
      {
        ...oldMessage(10, 3),
        'role': 'summary',
        'content': 'summary',
        'reference': jsonEncode({
          'coveredMessageIds': [1, 2],
          'throughMessageId': 2,
        }),
      },
    ];
    final original = '${rows.map(jsonEncode).join('\n')}\n';
    await write('sessions/10.jsonl', original);
    await write(
      'sessions/11.jsonl',
      '${[oldChat(11, 0), oldMessage(11, 1)].map(jsonEncode).join('\n')}\n',
    );
    await write('experiences/2/lesson.json', {
      'id': 'lesson',
      'sentinel_id': '2',
    });
    await write('sentinels/Reviewer/history/snapshot.json', {
      'snapshot_id': 'snapshot',
      'sentinel': {'id': 2, 'name': 'Reviewer'},
    });

    final second = FileStorage(root: storage.root);
    await Future.wait([storage.load(), second.load()]);
    final model = (await storage.modelRepository.getAllModels()).single;
    final provider =
        (await storage.providerRepository.getAllProviders()).single;
    final sentinel =
        (await storage.sentinelRepository.getAllSentinels()).single;
    final chats = await storage.sessionRepository.getAllChats();
    final first = chats.singleWhere((c) => c.title == 'chat-10');
    final other = chats.singleWhere((c) => c.title == 'chat-11');
    final messages = await storage.sessionRepository.getMessagesByChatId(
      first.id!,
    );
    final otherMessage = (await storage.sessionRepository.getMessagesByChatId(
      other.id!,
    )).single;
    expect([
      model.id,
      provider.id,
      sentinel.id,
      first.id,
      ...messages.map((m) => m.id),
    ], everyElement(matches(uuid7)));
    expect(model.modelId, 'model-name');
    expect(model.providerId, provider.id);
    expect(first.modelId, model.id);
    expect(first.sentinelId, sentinel.id);
    expect(other.sentinelId, isNull);
    expect(messages.map((m) => m.seq), [1, 2, 3]);
    expect(messages.first.id, isNot(otherMessage.id));
    expect(
      ConversationSummary.coveredIds(messages.last),
      messages.take(2).map((m) => m.id).toSet(),
    );
    expect(ConversationSummary.activeHistory(messages), [messages.last]);
    for (final state in [
      messages.first.responsesState,
      messages.first.messagesState,
      messages.first.chatCompletionsState,
    ]) {
      expect(jsonDecode(state), {...originalState, 'provider_id': provider.id});
    }
    expect(storage.legacyModelIds['3'], model.id);
    expect(second.legacyModelIds, storage.legacyModelIds);
    expect(
      await File(
        p.join(storage.root.path, 'backups/ids-v1/sessions/10.jsonl'),
      ).readAsString(),
      original,
    );
    expect(
      await File(p.join(storage.root.path, 'sessions/10.jsonl')).exists(),
      isFalse,
    );
    expect(await storage.metaFile.exists(), isFalse);
    final experience =
        jsonDecode(
              await File(
                p.join(
                  storage.root.path,
                  'experiences',
                  sentinel.id!,
                  'lesson.json',
                ),
              ).readAsString(),
            )
            as Map;
    expect(experience['sentinel_id'], sentinel.id);
    final snapshot =
        jsonDecode(
              await File(
                p.join(
                  storage.root.path,
                  'sentinels/by-id',
                  sentinel.id!,
                  'history/snapshot.json',
                ),
              ).readAsString(),
            )
            as Map;
    expect((snapshot['sentinel'] as Map)['id'], sentinel.id);
    await storage.load();
    expect(
      (await storage.sessionRepository.getAllChats()).map((c) => c.id).toSet(),
      chats.map((c) => c.id).toSet(),
    );
    final moved = await storage.root.rename(p.join(temp.path, 'moved'));
    final reopened = FileStorage(root: moved);
    await reopened.load();
    expect(
      (await reopened.sessionRepository.getChatById(first.id!))!.modelId,
      model.id,
    );
  });

  test('提交中断后从 ready 清单恢复，沿用已生成的身份', () async {
    await write('models.json', [
      {'id': 1},
    ]);
    // 模型现在归在 provider 名下,迁移源里要有一个同 id 的 provider,
    // 它才落得进 providers/{fixed-provider}.yaml
    await write('setting.yaml', '''
providers:
  - id: "fixed-provider"
    name: "Fixed"
    baseUrl: "https://fixed.example/v1"
    apiKey: "k"
''');
    final staged = [
      {'id': 'fixed-model', 'provider_id': 'fixed-provider'},
    ];
    await write('.id-migration-v2/0.new', staged);
    await write('.id-migration-v2/ready.json', {
      'files': [
        {'source': 'models.json', 'target': 'models.json', 'staged': '0.new'},
        {'source': '@settings', 'target': '@settings', 'staged': '1.new'},
      ],
      'legacy_model_ids': {'1': 'fixed-model'},
    });
    await write(
      '.id-migration-v2/1.new',
      jsonEncode({
        'providers': [
          {
            'id': 'fixed-provider',
            'name': 'Fixed',
            'baseUrl': 'https://fixed.example/v1',
            'apiKey': 'k',
          },
        ],
      }),
    );
    await storage.load();
    expect(
      (await storage.modelRepository.getAllModels()).single.id,
      'fixed-model',
    );
    expect(storage.legacyModelIds['1'], 'fixed-model');
    await storage.load();
    expect(
      (await storage.modelRepository.getAllModels()).single.id,
      'fixed-model',
    );
  });

  test('压缩步骤迁移保留消息序号、覆盖范围与运行编号', () async {
    final rows = [
      {'type': 'chat', 'id': 8, 'model_id': 3, 'sentinel_id': 0},
      {'type': 'message', 'id': 2, 'chat_id': 8, 'role': 'user'},
      {
        'type': 'message',
        'id': 5,
        'chat_id': 8,
        'role': 'compaction',
        'content': 'summary',
        'reference': jsonEncode({
          'compactionId': '8:5',
          'runId': 42,
          'phase': 'completed',
          'startedAt': '2026-01-01T00:00:00.000',
          'beforeTokens': 1000,
          'messageCount': 1,
          'coveredMessageIds': [2],
          'throughMessageId': 2,
        }),
      },
    ];
    await write('sessions/8.jsonl', '${rows.map(jsonEncode).join('\n')}\n');
    await storage.load();
    final chat = (await storage.sessionRepository.getAllChats()).single;
    final messages = await storage.sessionRepository.getMessagesByChatId(
      chat.id!,
    );
    final step = CompactionStep.fromMessage(messages.last);
    expect(step.seq, 5);
    expect(step.runId, 42);
    expect(step.throughSeq, 2);
    expect(step.coveredMessageIds, [messages.first.id]);
    expect(step.compactionId, '${chat.id}:${messages.last.id}');
    expect(step.toMessage().seq, 5);
    expect(ConversationSummary.activeHistory(messages), [messages.last]);
    final appended = await storage.sessionRepository.storeMessage(
      MessageEntity(chatId: chat.id!, role: 'user', content: 'continue'),
    );
    expect(appended.seq, 6);
  });

  test('旧版 storage_version.json 被认作已完成迁移，并原地改名', () async {
    final state = {
      'version': StorageIdMigration.version,
      'legacy_model_ids': {'3': 'id-3'},
    };
    await write('storage_version.json', state);
    await storage.load();
    expect(storage.legacyModelIds, {'3': 'id-3'});
    expect(
      await File(p.join(storage.root.path, 'storage_version.json')).exists(),
      isFalse,
    );
    expect(
      jsonDecode(
        await File(
          p.join(storage.root.path, '.storage_version'),
        ).readAsString(),
      ),
      state,
    );
  });

  test('歧义的重复 ID 中止迁移，原始文件与备份完整保留', () async {
    final data = [
      {'id': 1, 'name': 'a'},
      {'id': 1, 'name': 'b'},
    ];
    await write('models.json', data);
    await expectLater(storage.load(), throwsFormatException);
    expect(jsonDecode(await storage.modelsFile.readAsString()), data);
    expect(
      await File(p.join(storage.root.path, '.storage_version')).exists(),
      isFalse,
    );
    expect(
      jsonDecode(
        await File(
          p.join(storage.root.path, 'backups/ids-v1/models.json'),
        ).readAsString(),
      ),
      data,
    );
  });

  test('磁盘升级的身份转换保持模型与 provider 引用，字符串 ID 原样保留', () {
    final migrated = LegacyIdMap().convertCatalog({
      'providers': [
        {'id': 1},
      ],
      'models': [
        {'id': 2, 'provider_id': 1, 'model_id': 'api-model'},
      ],
      'sentinels': [
        {'id': 'existing-sentinel'},
      ],
    });
    expect(migrated['providers'][0]['id'], matches(uuid7));
    expect(
      migrated['models'][0]['provider_id'],
      migrated['providers'][0]['id'],
    );
    expect(migrated['models'][0]['model_id'], 'api-model');
    expect(migrated['sentinels'][0]['id'], 'existing-sentinel');
  });
}
