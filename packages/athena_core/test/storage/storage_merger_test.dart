import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_merger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

ProviderEntity _provider(int id, String name, {String key = ''}) =>
    ProviderEntity(
      id: id,
      name: name,
      baseUrl: 'https://$name.example/v1',
      apiKey: key,
      enabled: key.isNotEmpty,
      isPreset: true,
      createdAt: _now,
    );

ModelEntity _model(int id, String modelId, int providerId) => ModelEntity(
  id: id,
  name: modelId,
  modelId: modelId,
  providerId: providerId,
  contextWindow: 1,
  inputPrice: '',
  outputPrice: '',
  releasedAt: '',
  reasoning: true,
  vision: false,
  isPreset: true,
  createdAt: _now,
  updatedAt: _now,
);

SentinelEntity _sentinel(int id, String name) => SentinelEntity(
  id: id,
  name: name,
  avatar: '',
  description: '',
  prompt: 'p',
  tags: '',
  isPreset: false,
);

ChatEntity _chat(int id, String title, {int modelId = 1, int sentinelId = 1}) =>
    ChatEntity(
      id: id,
      title: title,
      modelId: modelId,
      sentinelId: sentinelId,
      createdAt: _now,
      updatedAt: _now,
      tokenTotal: id * 10,
    );

MessageEntity _message(int id, int chatId, String content) => MessageEntity(
  id: id,
  chatId: chatId,
  role: 'user',
  content: content,
);

/// 2 provider、2 model、1 sentinel、2 chat 各 2 条消息。
StorageSnapshot _snapshot() => StorageSnapshot(
  providers: [_provider(1, 'Deep Seek', key: 'sk-old'), _provider(2, 'Custom')],
  models: [_model(1, 'deepseek-v4', 1), _model(2, 'custom-1', 2)],
  sentinels: [_sentinel(1, 'Athena')],
  sessions: [
    SessionSnapshot(
      chat: _chat(1, 'first'),
      messages: [_message(1, 1, 'hi'), _message(2, 1, 'hello')],
    ),
    SessionSnapshot(
      chat: _chat(2, 'second', modelId: 2),
      messages: [_message(3, 2, 'q'), _message(4, 2, 'a')],
    ),
  ],
);

void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_merge_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    await storage.load();
  });

  tearDown(() => tmp.delete(recursive: true));

  test('空目标:全部保留原 id,计数抬高,种子不重复', () async {
    await StorageMerger(storage).merge(_snapshot());
    await const SentinelSeed().applyIfNeeded(
      sentinelRepo: storage.sentinelRepository,
    );

    final providers = await storage.providerRepository.getAllProviders();
    expect(providers.map((e) => e.id), [1, 2]);
    expect(providers.first.apiKey, 'sk-old');
    expect((await storage.modelRepository.getAllModels()).map((e) => e.id), [
      1,
      2,
    ]);
    expect((await storage.sentinelRepository.getAllSentinels()).length, 1);

    final chats = await storage.sessionRepository.getAllChats();
    expect(chats.map((e) => e.id).toSet(), {1, 2});
    expect((await storage.sessionRepository.getChatById(1))!.tokenTotal, 10);
    final msgs = await storage.sessionRepository.getMessagesByChatId(1);
    expect(msgs.map((m) => m.id), [1, 2]);
    expect(msgs.map((m) => m.content), ['hi', 'hello']);

    // 计数已抬高:新建不会与导入的撞号
    expect(
      await storage.sessionRepository.createChat(_chat(0, 'new')),
      3,
    );
    expect(await storage.modelRepository.createModel(_model(0, 'x', 1)), 3);
    expect(
      await storage.sentinelRepository.createSentinel(_sentinel(0, 'y')),
      2,
    );
    expect(
      await storage.sessionRepository.storeMessage(_message(0, 1, 'z')),
      3,
    );
  });

  test('目标已有数据:按名字/模型匹配合并,冲突 id 重分配并重映射', () async {
    // 模拟另一端已先写入:同名 provider(无 key)、同模型、另一个角色、会话 1
    expect(
      await storage.providerRepository.storeProvider(
        _provider(0, 'Deep Seek').copyWith(id: null).let((p) {
          return ProviderEntity.fromJson(p.toJson()..remove('id'));
        }),
      ),
      1,
    );
    expect(await storage.modelRepository.createModel(_model(0, 'deepseek-v4', 1)), 1);
    expect(await storage.sentinelRepository.createSentinel(_sentinel(0, 'Other')), 1);
    expect(await storage.sessionRepository.createChat(_chat(0, 'tui chat')), 1);

    await StorageMerger(storage).merge(_snapshot());

    // provider:Deep Seek 命中同名 → 沿用 id 1 并补上 key;Custom 保留 id 2
    final providers = await storage.providerRepository.getAllProviders();
    expect(providers.map((e) => '${e.id}:${e.name}'), ['1:Deep Seek', '2:Custom']);
    expect(providers.first.apiKey, 'sk-old');

    // 模型:deepseek-v4 命中 → id 1;custom-1 旧 id 2 未占用 → 保留
    final models = await storage.modelRepository.getAllModels();
    expect(models.map((e) => '${e.id}:${e.modelId}'), ['1:deepseek-v4', '2:custom-1']);

    // 角色:Athena 旧 id 1 被 Other 占用 → 新 id 2
    final sentinels = await storage.sentinelRepository.getAllSentinels();
    expect(sentinels.map((e) => '${e.id}:${e.name}'), ['1:Other', '2:Athena']);

    // 会话:旧 1 被占用 → 新 id 3;旧 2 空闲 → 保留;sentinel_id 重映射为 2
    final chats = await storage.sessionRepository.getAllChats();
    final byTitle = {for (final c in chats) c.title: c};
    expect(byTitle.keys.toSet(), {'tui chat', 'first', 'second'});
    expect(byTitle['tui chat']!.id, 1);
    expect(byTitle['second']!.id, 2);
    expect(byTitle['first']!.id, 3);
    expect(byTitle['first']!.sentinelId, 2);
    expect(byTitle['first']!.modelId, 1);
    final msgs = await storage.sessionRepository.getMessagesByChatId(3);
    expect(msgs.map((m) => m.chatId).toSet(), {3});
    expect(msgs.map((m) => m.content), ['hi', 'hello']);
  });

  test('未被会话引用的预设模型不并入,用户自建模型全部并入', () async {
    await StorageMerger(storage).merge(
      StorageSnapshot(
        providers: [_provider(1, 'P')],
        models: [
          _model(1, 'used-preset', 1),
          _model(2, 'stale-preset', 1),
          _model(3, 'mine', 1).copyWith(isPreset: false),
        ],
        sessions: [
          SessionSnapshot(chat: _chat(1, 'c', modelId: 1), messages: const []),
        ],
      ),
    );
    final models = await storage.modelRepository.getAllModels();
    expect(models.map((m) => m.modelId).toSet(), {'used-preset', 'mine'});
  });

  test('重复合并同一份快照不会写重', () async {
    await StorageMerger(storage).merge(_snapshot());
    await StorageMerger(storage).merge(_snapshot());
    expect((await storage.providerRepository.getAllProviders()).length, 2);
    expect((await storage.modelRepository.getAllModels()).length, 2);
    expect((await storage.sentinelRepository.getAllSentinels()).length, 1);
    expect((await storage.sessionRepository.getAllChats()).length, 2);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
