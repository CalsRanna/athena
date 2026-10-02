import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late FileStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('athena_format_storage_');
    storage = FileStorage(root: directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test('缺省 apiFormat 默认兼容格式并允许自动同步，显式格式默认手动', () async {
    await _writeProvider(storage, 'legacy', 'name: Legacy\n');
    await _writeProvider(
      storage,
      'manual',
      'name: Manual\napiFormat: messages\n',
    );
    await _writeProvider(
      storage,
      'invalid',
      'name: Invalid\napiFormat: [responses]\n',
    );
    final byName = {
      for (final p in await storage.providerRepository.getAllProviders())
        p.name: p,
    };
    expect(byName['Legacy']!.apiFormat, ApiFormat.chatCompletions);
    expect(byName['Legacy']!.apiFormatAuto, isTrue);
    expect(byName['Manual']!.apiFormat, ApiFormat.messages);
    expect(byName['Manual']!.apiFormatAuto, isFalse);
    expect(byName['Invalid']!.apiFormat, ApiFormat.chatCompletions);
  });

  test('保存 TUI 默认模型不会改变 provider 的自动模式', () async {
    await _writeProvider(storage, 'legacy', 'name: Legacy\n');
    await _writeProvider(
      storage,
      'manual',
      'name: Manual\napiFormat: messages\n',
    );
    await storage.userSettings.saveModelId('test-model');
    final byName = {
      for (final p in await storage.providerRepository.getAllProviders())
        p.name: p,
    };
    expect(byName['Legacy']!.apiFormat, ApiFormat.chatCompletions);
    expect(byName['Legacy']!.apiFormatAuto, isTrue);
    expect(byName['Manual']!.apiFormat, ApiFormat.messages);
    expect(byName['Manual']!.apiFormatAuto, isFalse);
    expect(await storage.userSettings.loadModelId(), 'test-model');
  });

  test('格式与自动模式经过 YAML 与 JSON 序列化仍保留', () async {
    for (final format in ApiFormat.values) {
      for (final automatic in [true, false]) {
        final provider = _provider().copyWith(
          apiFormat: format,
          apiFormatAuto: automatic,
        );
        final id = await storage.providerRepository.storeProvider(provider);
        // 另一个实例重新读盘：格式确实写进了 YAML，而不只是留在内存
        final reopened = FileStorage(root: directory);
        final saved = (await reopened.providerRepository.getProviderById(id))!;
        expect(saved.apiFormat, format);
        expect(saved.apiFormatAuto, automatic);
        // JSON 序列化往返（旧备份的字段形态）也要保留这两个字段
        final restored = ProviderEntity.fromJson(
          jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
        );
        expect(restored.apiFormat, format);
        expect(restored.apiFormatAuto, automatic);
        expect(restored.copyWith(apiKey: 'updated').apiFormat, format);
        expect(restored.copyWith(apiKey: 'updated').apiFormatAuto, automatic);
      }
    }
  });

  test('旧 JSON 缺少格式字段时按兼容格式与自动模式降级', () {
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

/// 直接写一个 provider 文件:模拟用户手工编辑这个目录(文件即身份,
/// 内容里不必有 id)。
Future<void> _writeProvider(FileStorage storage, String id, String body) =>
    atomicWriteString(
      File(p.join(storage.providersDir.path, '$id.yaml')),
      body,
    );

ProviderEntity _provider() => ProviderEntity(
  name: 'Example',
  baseUrl: 'https://example.com/v1',
  apiKey: 'old-key',
  isPreset: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);
