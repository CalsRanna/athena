import 'dart:io';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/storage/user_settings_store.dart';
import 'package:athena_tui/storage/yaml_provider_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_settings_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ProviderEntity provider(String name, String apiKey, {int? id}) =>
      ProviderEntity(
        id: id,
        name: name,
        baseUrl: 'https://example.com/v1',
        apiKey: apiKey,
        enabled: false,
        isPreset: true,
        createdAt: DateTime(2026, 1, 1),
      );

  group('UserSettingsStore', () {
    late File file;
    late UserSettingsStore store;

    setUp(() {
      file = File('${tempDir.path}/setting.yaml');
      store = UserSettingsStore(file: file);
    });

    test('providers 保存后可从 yaml 读回(含 id/apiKey/baseUrl)', () async {
      await store.saveProviders([
        provider('Deep Seek', 'sk-ds-123', id: 1),
        provider('Open Router', '', id: 2),
      ]);

      final providers = await store.loadProviders();
      expect(providers, hasLength(2));
      expect(providers[0].id, 1);
      expect(providers[0].name, 'Deep Seek');
      expect(providers[0].apiKey, 'sk-ds-123');
      expect(providers[0].baseUrl, 'https://example.com/v1');
      expect(providers[1].apiKey, '');
      expect(await file.exists(), isTrue);
    });

    test('apiKey 含特殊字符正确转义与读回', () async {
      await store.saveProviders([
        provider('硅基流动', 'sk-abc:def/ghi+jkl', id: 1),
      ]);

      final providers = await store.loadProviders();
      expect(providers.single.apiKey, 'sk-abc:def/ghi+jkl');
      expect(providers.single.name, '硅基流动');
    });

    test('model 保存/读回(modelId 字符串)', () async {
      expect(await store.loadModelId(), isNull);

      await store.saveModelId('deepseek-v4-flash');
      expect(await store.loadModelId(), 'deepseek-v4-flash');
    });

    test('文件不存在时返回空配置', () async {
      expect(await store.loadProviders(), isEmpty);
      expect(await store.loadModelId(), isNull);
    });

    test('损坏的 yaml 按空配置处理,不抛异常', () async {
      await file.writeAsString('not: [valid: yaml\n   :::');
      expect(await store.loadProviders(), isEmpty);
    });

    test('旧 GUI 遗留键被丢弃,写回不残留', () async {
      // 旧格式:含 currentModel/models 脏段 + providers
      await file.writeAsString(
        'currentModel: openrouter-free\n'
        'models:\n'
        '  - name: openrouter-free\n'
        '    apiKey: sk-old\n'
        'providers:\n'
        '  - name: Deep Seek\n'
        '    apiKey: sk-new\n',
      );

      // 读回只认 providers
      final providers = await store.loadProviders();
      expect(providers, hasLength(1));
      expect(providers.single.apiKey, 'sk-new');

      // 写回(如保存 model)后,残留键被清掉
      await store.saveModelId('deepseek-chat');
      final content = await file.readAsString();
      expect(content.contains('currentModel'), isFalse);
      expect(content.contains('models:'), isFalse);
      expect(content.contains('providers:'), isTrue);
    });
  });

  group('YamlProviderRepository', () {
    late YamlProviderRepository repo;
    late UserSettingsStore store;

    setUp(() {
      store = UserSettingsStore(file: File('${tempDir.path}/setting.yaml'));
      repo = YamlProviderRepository(store: store);
    });

    test('storeProvider 分配自增 id,不写 yaml(内存权威)', () async {
      final id1 = await repo.storeProvider(provider('Deep Seek', 'sk-1'));
      final id2 = await repo.storeProvider(provider('Open Router', 'sk-2'));
      expect(id1, 1);
      expect(id2, 2);

      // storeProvider(空 key 模板)不落 yaml
      final store = UserSettingsStore(file: File('${tempDir.path}/setting.yaml'));
      expect(await store.loadProviders(), isEmpty);
    });

    test('updateProvider 配 key 后写入 yaml', () async {
      final id = await repo.storeProvider(provider('Deep Seek', ''));
      await repo.updateProvider(
        (await repo.getProviderById(id))!.copyWith(apiKey: 'sk-1'),
      );

      // 配了 key 的 provider 出现在 yaml
      final store = UserSettingsStore(file: File('${tempDir.path}/setting.yaml'));
      final saved = await store.loadProviders();
      expect(saved, hasLength(1));
      expect(saved.single.apiKey, 'sk-1');
    });

    test('updateProvider 修改 apiKey 持久化', () async {
      final id = await repo.storeProvider(provider('Deep Seek', 'sk-old'));
      final all = await repo.getAllProviders();
      await repo.updateProvider(all.first.copyWith(apiKey: 'sk-new'));

      final reloaded = await repo.getProviderById(id);
      expect(reloaded!.apiKey, 'sk-new');
    });

    test('importProviders 保留原始 id', () async {
      await repo.importProviders([
        provider('Deep Seek', 'sk-1', id: 7),
        provider('Open Router', 'sk-2', id: 9),
      ]);

      final all = await repo.getAllProviders();
      expect(all.map((p) => p.id).toSet(), {7, 9});
      // 之后 storeProvider 新 provider 从 max+1 分配
      final newId = await repo.storeProvider(provider('New', 'sk-3'));
      expect(newId, 10);
    });

    test('deleteProvider 与 getProvidersCount', () async {
      final id1 = await repo.storeProvider(provider('A', 'sk-1'));
      await repo.storeProvider(provider('B', 'sk-2'));
      await repo.deleteProvider(id1);

      expect(await repo.getProvidersCount(), 1);
      expect(await repo.getProviderByName('B'), isNotNull);
      expect(await repo.getProviderByName('A'), isNull);
    });
  });

  group('TuiDi 集成', () {
    test('旧 providers.jsonl 一次性迁移,只把配 key 的写 yaml', () async {
      // 预置旧格式 providers.jsonl(含 apiKey;旧存储用 toJson 写,
      // 字段为 snake_case,与 ProviderEntity.fromJson 一致)
      final legacyDir = Directory('${tempDir.path}/legacy');
      await Directory('${legacyDir.path}/messages').create(recursive: true);
      await File('${legacyDir.path}/providers.jsonl').writeAsString(
        '{"id":1,"name":"Deep Seek","base_url":"https://api.deepseek.com/v1",'
        '"api_key":"sk-legacy","enabled":false,"is_preset":true}\n',
      );

      final di = TuiDi(
        dataDirectory: legacyDir.path,
        homeDir: tempDir.path,
      );
      await di.initialize(syncModels: false);

      // 内存:迁移的 Deep Seek + seed 补齐的模板 provider
      final providers = await di.providerRepo.getAllProviders();
      final deepSeek = providers.firstWhere((p) => p.name == 'Deep Seek');
      expect(deepSeek.apiKey, 'sk-legacy');
      expect(deepSeek.id, 1);
      // seed 补齐了模板 provider(空 key)
      expect(providers.length, greaterThanOrEqualTo(2));

      // yaml 只存配了 key 的(Deep Seek),空 key 的模板不落盘
      final store = UserSettingsStore(file: File(di.userSettingsFile.path));
      final saved = await store.loadProviders();
      expect(saved, hasLength(1));
      expect(saved.single.name, 'Deep Seek');
      expect(saved.single.apiKey, 'sk-legacy');
      // 旧 jsonl 已删除(避免重复迁移)
      expect(await File('${legacyDir.path}/providers.jsonl').exists(), isFalse);
    });

    test('switchModel 后 yaml 持久化 modelId', () async {
      final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);
      await di.chatController.initialize();

      // availableModels 只含已配 key 的 provider 的模型:先给 Deep Seek 配 key
      final providers = await di.chatController.availableProviders;
      await di.chatController.updateProviderApiKey(
        providers.firstWhere((p) => p.name == 'Deep Seek'),
        'sk-test-123',
      );

      final models = await di.chatController.availableModels;
      expect(models, isNotEmpty);
      await di.chatController.switchModel(models.first);

      // 切换到模型后,modelId 被写回 yaml
      final store = UserSettingsStore(file: File(di.userSettingsFile.path));
      expect(await store.loadModelId(), models.first.modelId);
    });

    test('updateProviderApiKey 直接持久化到 yaml(无需额外写回)', () async {
      final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);
      await di.chatController.initialize();

      final providers = await di.chatController.availableProviders;
      final target = providers.firstWhere((p) => p.name == 'Deep Seek');
      await di.chatController.updateProviderApiKey(target, 'sk-persist-1');

      final store = UserSettingsStore(file: File(di.userSettingsFile.path));
      final loaded = await store.loadProviders();
      expect(
        loaded.firstWhere((p) => p.name == 'Deep Seek').apiKey,
        'sk-persist-1',
      );
    });
  });
}
