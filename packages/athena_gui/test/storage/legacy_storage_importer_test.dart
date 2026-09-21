import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/storage/legacy_storage_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 用真实 migration 建一个小 SQLite 库当夹具:2 provider、2 model、
/// 1 sentinel(Athena 预设)、2 chat 各 2 条消息。
Future<File> _buildFixture(Directory dir) async {
  final dbFile = File(p.join(dir.path, 'athena.db'));
  await Database.instance.ensureInitialized(path: dbFile.path);
  final laconic = Database.instance.laconic;
  final now = DateTime.now().millisecondsSinceEpoch;
  await laconic.statement(
    'INSERT INTO providers(id,name,base_url,api_key,enabled,is_preset,created_at) '
    'VALUES (1,"Deep Seek","https://api.deepseek.com/v1","sk-old",1,1,$now),'
    '(2,"Custom","https://custom.example/v1","",0,0,$now)',
  );
  await laconic.statement(
    'INSERT INTO models(id,name,model_id,provider_id,context_window,is_preset,created_at,updated_at) '
    'VALUES (1,"DeepSeek V4","deepseek-v4",1,128000,1,$now,$now),'
    '(2,"Custom Model","custom-1",2,8000,0,$now,$now)',
  );
  await laconic.statement(
    'INSERT INTO chats(id,title,model_id,sentinel_id,created_at,updated_at,token_total) '
    'VALUES (1,"first",1,1,$now,$now,42),(2,"second",2,1,$now,$now,0)',
  );
  await laconic.statement(
    'INSERT INTO messages(id,chat_id,role,content,reasoning_started_at,reasoning_updated_at) '
    'VALUES (1,1,"user","hi",$now,$now),(2,1,"assistant","hello",$now,$now),'
    '(3,2,"user","q",$now,$now),(4,2,"assistant","a",$now,$now)',
  );
  await laconic.close();
  return dbFile;
}

void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_import_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('空目标:全部保留原 id,旧库改名为 .migrated', () async {
    final dbFile = await _buildFixture(tmp);
    await storage.load();
    final imported = await LegacyStorageImporter(
      storage: storage,
      dbFile: dbFile,
    ).importIfNeeded();
    await const SentinelSeed().applyIfNeeded(
      sentinelRepo: storage.sentinelRepository,
    );

    expect(imported, isTrue);
    expect(await dbFile.exists(), isFalse);
    expect(await File('${dbFile.path}.migrated').exists(), isTrue);

    final providers = await storage.providerRepository.getAllProviders();
    expect(providers.map((e) => e.id), [1, 2]);
    expect(providers.first.apiKey, 'sk-old');
    // yaml 持久化了全部 provider(含空 key 的)
    await storage.load();
    expect((await storage.providerRepository.getAllProviders()).length, 2);

    final models = await storage.modelRepository.getAllModels();
    expect(models.map((e) => e.id), [1, 2]);
    expect(models.last.providerId, 2);

    // 迁移后种子看到已有角色,不再重复创建
    final sentinels = await storage.sentinelRepository.getAllSentinels();
    expect(sentinels.length, 1);
    expect(sentinels.single.id, 1);

    final chats = await storage.sessionRepository.getAllChats();
    expect(chats.map((e) => e.id).toSet(), {1, 2});
    expect((await storage.sessionRepository.getChatById(1))!.tokenTotal, 42);
    final msgs = await storage.sessionRepository.getMessagesByChatId(1);
    expect(msgs.map((m) => m.id), [1, 2]);
    expect(msgs.map((m) => m.content), ['hi', 'hello']);

    // 计数已抬高:新建会话/消息不会与导入的撞号
    final newChatId = await storage.sessionRepository.createChat(
      chats.first.copyWith(title: 'new'),
    );
    expect(newChatId, 3);
    expect(await storage.modelRepository.createModel(models.first), 3);

    // 第二次启动:没有旧库,直接跳过
    expect(
      await LegacyStorageImporter(storage: storage, dbFile: dbFile)
          .importIfNeeded(),
      isFalse,
    );
  });

  test('目标已有数据:按名字/模型匹配合并,冲突 id 重新分配并重映射', () async {
    final dbFile = await _buildFixture(tmp);
    // 模拟 TUI 已先写入:同名 provider(无 key)、同模型、另一个角色、会话 1
    await storage.load();
    final pid = await storage.providerRepository.storeProvider(
      ProviderEntity(
        name: 'Deep Seek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: '',
        enabled: false,
        isPreset: true,
        createdAt: DateTime.now(),
      ),
    );
    expect(pid, 1);
    final now = DateTime.now();
    expect(
      await storage.modelRepository.createModel(
        ModelEntity(
          name: 'DeepSeek V4',
          modelId: 'deepseek-v4',
          providerId: 1,
          contextWindow: 1,
          inputPrice: '',
          outputPrice: '',
          releasedAt: '',
          reasoning: true,
          vision: false,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      1,
    );
    expect(
      await storage.sentinelRepository.createSentinel(
        SentinelEntity(
          name: 'Other',
          avatar: '',
          description: '',
          prompt: 'x',
          tags: '',
          isPreset: false,
        ),
      ),
      1,
    );
    expect(
      await storage.sessionRepository.createChat(
        ChatEntity(
          title: 'tui chat',
          modelId: 1,
          sentinelId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      1,
    );

    await LegacyStorageImporter(storage: storage, dbFile: dbFile)
        .importIfNeeded();

    // provider:Deep Seek 命中同名 → 沿用 id 1 并补上旧 key;Custom 保留 id 2
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
}
