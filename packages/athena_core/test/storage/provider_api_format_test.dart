import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late FileStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('athena_format_storage_');
    storage = FileStorage(root: directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test('旧 YAML 默认兼容格式并允许自动同步，显式格式默认手动', () async {
    await atomicWriteString(storage.settingFile, '''
providers:
  - id: 1
    name: Legacy
  - id: 2
    name: Manual
    apiFormat: messages
  - id: 3
    name: Invalid
    apiFormat: [responses]
''');
    final providers = await storage.providerRepository.getAllProviders();
    expect(providers[0].apiFormat, ApiFormat.chatCompletions);
    expect(providers[0].apiFormatAuto, isTrue);
    expect(providers[1].apiFormat, ApiFormat.messages);
    expect(providers[1].apiFormatAuto, isFalse);
    expect(providers[2].apiFormat, ApiFormat.chatCompletions);
  });

  test('保存 TUI 默认模型不会改变旧配置与显式配置的自动模式', () async {
    await atomicWriteString(storage.settingFile, '''
providers:
  - id: 1
    name: Legacy
  - id: 2
    name: Manual
    apiFormat: messages
''');
    await storage.userSettings.saveModelId('test-model');
    final providers = await storage.providerRepository.getAllProviders();
    expect(providers[0].apiFormat, ApiFormat.chatCompletions);
    expect(providers[0].apiFormatAuto, isTrue);
    expect(providers[1].apiFormat, ApiFormat.messages);
    expect(providers[1].apiFormatAuto, isFalse);
    expect(await storage.userSettings.loadModelId(), 'test-model');
  });

  test('格式与自动模式经过 YAML、JSON 备份和导入仍保留', () async {
    for (final format in ApiFormat.values) {
      for (final automatic in [true, false]) {
        final provider = _provider().copyWith(
          apiFormat: format,
          apiFormatAuto: automatic,
        );
        final id = await storage.providerRepository.storeProvider(provider);
        final reopened = FileStorage(root: directory);
        final saved = (await reopened.providerRepository.getProviderById(id))!;
        final restored = ProviderEntity.fromJson(
          jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
        );
        await reopened.providerRepository.importProviders([restored]);
        final imported = (await storage.providerRepository.getProviderById(
          id,
        ))!;
        expect(imported.apiFormat, format);
        expect(imported.apiFormatAuto, automatic);
        expect(imported.copyWith(apiKey: 'updated').apiFormat, format);
        expect(imported.copyWith(apiKey: 'updated').apiFormatAuto, automatic);
      }
    }
  });

  test('旧 JSON 备份缺少格式时仍可导入', () {
    final json = _provider().toJson()
      ..remove('api_format')
      ..remove('api_format_auto');
    final legacy = ProviderEntity.fromJson(json);
    expect(legacy.apiFormat, ApiFormat.chatCompletions);
    expect(legacy.apiFormatAuto, isTrue);
    json['api_format'] = 'responses';
    expect(ProviderEntity.fromJson(json).apiFormatAuto, isFalse);
  });

  test('两个实例并发写入时格式同步保留凭据编辑', () async {
    final id = await storage.providerRepository.storeProvider(_provider());
    final other = FileStorage(root: directory);
    final edited = (await other.providerRepository.getProviderById(
      id,
    ))!.copyWith(apiKey: 'new-key', enabled: true);
    await Future.wait([
      other.providerRepository.updateProvider(edited),
      storage.providerRepository.syncApiFormat(
        id: id,
        baseUrl: edited.baseUrl,
        apiFormat: ApiFormat.responses,
      ),
    ]);
    // 最后再同步一次，覆盖可能由旧编辑快照带回的自动格式；凭据不能回退。
    await storage.providerRepository.syncApiFormat(
      id: id,
      baseUrl: edited.baseUrl,
      apiFormat: ApiFormat.responses,
    );
    final saved = (await other.providerRepository.getProviderById(id))!;
    expect(saved.apiKey, 'new-key');
    expect(saved.enabled, isTrue);
    expect(saved.apiFormat, ApiFormat.responses);
  });

  test('仓储同步在写入前检查手动选择、自定义端点和非预设状态', () async {
    for (final provider in [
      _provider().copyWith(apiFormat: ApiFormat.messages),
      _provider().copyWith(baseUrl: 'https://other.example/v1'),
      _provider().copyWith(isPreset: false),
    ]) {
      final id = await storage.providerRepository.storeProvider(provider);
      await storage.providerRepository.syncApiFormat(
        id: id,
        baseUrl: _provider().baseUrl,
        apiFormat: ApiFormat.responses,
      );
      final saved = (await storage.providerRepository.getProviderById(id))!;
      expect(saved.apiFormat, provider.apiFormat);
      expect(saved.apiFormatAuto, provider.apiFormatAuto);
      expect(saved.baseUrl, provider.baseUrl);
    }
  });
}

ProviderEntity _provider() => ProviderEntity(
  name: 'Example',
  baseUrl: 'https://example.com/v1',
  apiKey: 'old-key',
  isPreset: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);
