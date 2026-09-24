import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/model_catalog_config.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late FileStorage storage;
  late ModelCatalogService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('athena_api_format_');
    storage = FileStorage(root: directory);
    service = _service(storage);
  });
  tearDown(() => directory.delete(recursive: true));

  test('供应商 SDK 提供默认格式，未知 SDK 与模型级提示不猜测', () {
    const config = CatalogProviderConfig(
      sourceId: 'example',
      localName: 'Example',
      localBaseUrl: 'https://example.com/v1',
    );
    expect(
      config.resolveApiFormat({'npm': '@ai-sdk/anthropic'}),
      ApiFormat.messages,
    );
    expect(config.resolveApiFormat({'npm': '@unknown/provider'}), isNull);
    expect(config.resolveApiFormat({'api': 'https://example.com/v1'}), isNull);
    expect(
      config.resolveApiFormat({
        'npm': '@openrouter/ai-sdk-provider',
        'models': {
          'one': {
            'provider': {'shape': 'responses'},
          },
          'two': {
            'provider': {'npm': '@ai-sdk/anthropic'},
          },
        },
      }),
      ApiFormat.chatCompletions,
      reason: '模型的特殊调用方式不能覆盖整个供应商的默认格式',
    );
  });

  test('新建预设同步格式，并在重新读取配置后保留', () async {
    await service.applyCatalog({
      ..._catalog('openai', '@ai-sdk/openai'),
      ..._catalog('deepseek', '@ai-sdk/openai-compatible'),
    });
    final reopened = FileStorage(root: directory);
    final openai = (await reopened.providerRepository.getPresetProviderByName(
      'OpenAI',
    ))!;
    final deepseek = (await reopened.providerRepository.getPresetProviderByName(
      'Deep Seek',
    ))!;
    expect(openai.apiFormat, ApiFormat.responses);
    expect(openai.apiFormatAuto, isTrue);
    expect(deepseek.apiFormat, ApiFormat.chatCompletions);
    expect(deepseek.apiFormatAuto, isTrue);
  });

  test('Google 与 MiniMax 的本地兼容端点优先于上游原生 SDK', () async {
    await service.applyCatalog({
      ..._catalog('google', '@ai-sdk/google'),
      ..._catalog('minimax', '@ai-sdk/anthropic'),
    });
    for (final name in ['Google', 'MiniMax']) {
      final provider = (await storage.providerRepository
          .getPresetProviderByName(name))!;
      expect(provider.apiFormat, ApiFormat.chatCompletions, reason: name);
      expect(
        provider.baseUrl,
        modelCatalogConfig.singleWhere((c) => c.localName == name).localBaseUrl,
      );
    }
  });

  test('已有预设更新自动格式，保留凭据、启用状态和端点', () async {
    final id = await storage.providerRepository.storeProvider(_openai());
    await service.applyCatalog(_catalog('openai', '@ai-sdk/openai'));
    final provider = (await storage.providerRepository.getProviderById(id))!;
    expect(provider.apiFormat, ApiFormat.responses);
    expect(provider.apiFormatAuto, isTrue);
    expect(provider.apiKey, 'test-key');
    expect(provider.enabled, isTrue);
    expect(provider.baseUrl, _openai().baseUrl);
    expect(provider.createdAt, _openai().createdAt);

    await service.applyCatalog(_catalog('openai', '@ai-sdk/openai-compatible'));
    expect(
      (await storage.providerRepository.getProviderById(id))!.apiFormat,
      ApiFormat.chatCompletions,
      reason: '自动模式下后续同步仍能更新元数据',
    );
  });

  test('手动格式与用户自定义的预设地址都不会被同步覆盖', () async {
    final id = await storage.providerRepository.storeProvider(
      _openai().copyWith(apiFormat: ApiFormat.messages),
    );
    await service.applyCatalog(_catalog('openai', '@ai-sdk/openai'));
    var provider = (await storage.providerRepository.getProviderById(id))!;
    expect(provider.apiFormat, ApiFormat.messages);
    expect(provider.apiFormatAuto, isFalse);

    await storage.providerRepository.updateProvider(
      provider.copyWith(
        baseUrl: 'https://gateway.example/v1',
        apiFormatAuto: true,
      ),
    );
    await service.applyCatalog(_catalog('openai', '@ai-sdk/openai'));
    provider = (await storage.providerRepository.getProviderById(id))!;
    expect(provider.apiFormat, ApiFormat.messages);
    expect(provider.baseUrl, 'https://gateway.example/v1');
  });

  test('上游 npm 缺失或未知时保留已经同步的格式', () async {
    final id = await storage.providerRepository.storeProvider(_openai());
    await service.applyCatalog(_catalog('openai', '@ai-sdk/openai'));
    for (final npm in [null, '@unknown/provider', 123]) {
      await service.applyCatalog(_catalog('openai', npm));
      expect(
        (await storage.providerRepository.getProviderById(id))!.apiFormat,
        ApiFormat.responses,
      );
    }
  });

  test('新鲜缓存补齐旧配置的格式，不发网络请求也不重建模型', () async {
    final id = await storage.providerRepository.storeProvider(_openai());
    await _cache(storage, _catalog('openai', '@ai-sdk/openai'), DateTime.now());
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await _service(storage, client: client).syncIfNeeded();
    expect(requests, 0);
    expect(await storage.modelRepository.getModelsCount(), 0);
    expect(
      (await storage.providerRepository.getProviderById(id))!.apiFormat,
      ApiFormat.responses,
    );
  });

  test('网络同步失败时仍可由旧缓存补齐格式', () async {
    final id = await storage.providerRepository.storeProvider(_openai());
    await _cache(
      storage,
      _catalog('openai', '@ai-sdk/openai'),
      DateTime.now().subtract(const Duration(days: 8)),
    );
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    addTearDown(client.close);
    await _service(storage, client: client).syncIfNeeded();
    expect(
      (await storage.providerRepository.getProviderById(id))!.apiFormat,
      ApiFormat.responses,
    );
  });
}

ModelCatalogService _service(FileStorage storage, {http.Client? client}) {
  return ModelCatalogService(
    modelRepository: storage.modelRepository,
    providerRepository: storage.providerRepository,
    chatRepository: storage.sessionRepository,
    cacheFilePath: storage.catalogCacheFile.path,
    httpClient: client,
  );
}

ProviderEntity _openai() => ProviderEntity(
  name: 'OpenAI',
  baseUrl: 'https://api.openai.com/v1/',
  apiKey: 'test-key',
  enabled: true,
  isPreset: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

Map<String, dynamic> _catalog(String id, Object? npm) => {
  id: {
    if (npm != null) 'npm': npm,
    'models': {
      'test-model': {
        'name': 'Test model',
        'reasoning': true,
        'release_date': DateTime.now().toIso8601String().substring(0, 10),
      },
    },
  },
};

Future<void> _cache(
  FileStorage storage,
  Map<String, dynamic> data,
  DateTime fetchedAt,
) => atomicWriteString(
  storage.catalogCacheFile,
  jsonEncode({'fetched_at': fetchedAt.millisecondsSinceEpoch, 'data': data}),
);
