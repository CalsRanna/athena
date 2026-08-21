import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeModelRepository implements ModelRepository {
  final List<ModelEntity> models = [];
  int _nextId = 1;

  @override
  Future<int> createModel(ModelEntity model) async {
    final id = _nextId++;
    models.add(model.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateModel(ModelEntity model) async {
    final index = models.indexWhere((m) => m.id == model.id);
    if (index >= 0) models[index] = model;
  }

  @override
  Future<void> deleteModel(int id) async {
    models.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async {
    return models.where((m) => m.providerId == providerId).toList();
  }

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    int providerId,
  ) async {
    for (final m in models) {
      if (m.modelId == modelId && m.providerId == providerId) return m;
    }
    return null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProviderRepository implements ProviderRepository {
  final List<ProviderEntity> providers = [];
  int _nextId = 1;

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async {
    for (final p in providers) {
      if (p.name == name && p.isPreset) return p;
    }
    return null;
  }

  @override
  Future<int> storeProvider(ProviderEntity provider) async {
    final id = _nextId++;
    providers.add(provider.copyWith(id: id));
    return id;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatRepository implements ChatRepository {
  final Map<int, int> chatCounts = {};

  @override
  Future<int> getChatCountByModelId(int modelId) async =>
      chatCounts[modelId] ?? 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.statusCode, this.body);

  final int statusCode;
  final String body;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// 模拟 models.dev/api.json 片段(结构与真实数据一致)。
Map<String, dynamic> _fixtureCatalog() => {
  'deepseek': {
    'name': 'DeepSeek',
    'models': {
      'deepseek-chat': {
        'name': 'DeepSeek Chat',
        'limit': {'context': 1000000, 'output': 163840},
        'cost': {
          'input': 0.14,
          'output': 0.28,
          'cache_read': 0.0028,
        },
        'reasoning': true,
        'attachment': true,
        'release_date': '2025-12-01',
      },
      'deepseek-reasoner': {
        'name': 'DeepSeek Reasoner',
        'limit': {'context': 1000000},
        'cost': {'input': 0.14, 'output': 0.28},
        'reasoning': true,
        'release_date': '2025-05-28',
      },
    },
  },
};

ModelCatalogService _service(
  _FakeModelRepository modelRepo,
  _FakeProviderRepository providerRepo,
  _FakeChatRepository chatRepo, {
  http.Client? httpClient,
  String? cacheFilePath,
}) {
  return ModelCatalogService(
    modelRepository: modelRepo,
    providerRepository: providerRepo,
    chatRepository: chatRepo,
    httpClient: httpClient,
    cacheFilePath: cacheFilePath,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('formatPrice', () {
    test('整数价格去尾零', () {
      expect(ModelCatalogService.formatPrice(2), r'$2/M input tokens');
      expect(ModelCatalogService.formatPrice(12), r'$12/M input tokens');
    });

    test('小数价格保留有效位', () {
      expect(ModelCatalogService.formatPrice(0.14), r'$0.14/M input tokens');
      expect(ModelCatalogService.formatPrice(1.5), r'$1.5/M input tokens');
      expect(
        ModelCatalogService.formatPrice(0.0028),
        r'$0.0028/M input tokens',
      );
    });

    test('非数字返回空串', () {
      expect(ModelCatalogService.formatPrice(null), '');
      expect(ModelCatalogService.formatPrice('abc'), '');
    });
  });

  group('globMatch', () {
    test('支持 * 通配符', () {
      expect(
        ModelCatalogService.globMatch('anthropic/claude-*', 'anthropic/claude-sonnet-4.6'),
        isTrue,
      );
      expect(
        ModelCatalogService.globMatch('qwen/qwen3*', 'qwen/qwen3-14b'),
        isTrue,
      );
      expect(
        ModelCatalogService.globMatch('qwen/qwen3*', 'qwen/qwen3-235b-a22b-thinking-2507'),
        isTrue,
      );
      expect(ModelCatalogService.globMatch('qwen/qwen3*', 'qwen-max'), isFalse);
      expect(
        ModelCatalogService.globMatch('deepseek/*', 'openai/gpt-5'),
        isFalse,
      );
    });
  });

  group('selectModels', () {
    final models = {
      'anthropic/claude-sonnet-4.6': {'name': 'A'},
      'google/gemini-3.5-flash': {'name': 'B'},
      'qwen/qwen3-14b': {'name': 'C'},
    };

    test('include 为空时全部导入', () {
      final result = ModelCatalogService.selectModels(models);
      expect(result.keys.toSet(), models.keys.toSet());
    });

    test('include 过滤', () {
      final result = ModelCatalogService.selectModels(
        models,
        include: ['anthropic/*', 'qwen/qwen3*'],
      );
      expect(result.keys, containsAll(['anthropic/claude-sonnet-4.6', 'qwen/qwen3-14b']));
      expect(result.keys, isNot(contains('google/gemini-3.5-flash')));
    });

    test('exclude 优先级高于 include', () {
      final result = ModelCatalogService.selectModels(
        models,
        include: ['*'],
        exclude: ['qwen/*'],
      );
      expect(result.keys, isNot(contains('qwen/qwen3-14b')));
      expect(result.length, 2);
    });
  });

  group('filterReasoning', () {
    final models = {
      'openai/gpt-5': {'name': 'A', 'reasoning': true},
      'openai/gpt-4o': {'name': 'B', 'reasoning': false},
      'anthropic/claude-sonnet-5': {'name': 'C', 'reasoning': true},
      'bare-model': {'name': 'D'}, // reasoning 缺失 → 视为非推理
    };

    test('默认只保留 reasoning=true', () {
      final result = ModelCatalogService.filterReasoning(models);
      expect(result.keys.toSet(), {
        'openai/gpt-5',
        'anthropic/claude-sonnet-5',
      });
    });

    test('reasoningOnly=false 时不过滤', () {
      final result = ModelCatalogService.filterReasoning(
        models,
        reasoningOnly: false,
      );
      expect(result.keys.toSet(), models.keys.toSet());
    });

    test('过滤发生在家族去重之前:家族内非推理版本被剔,推理版保留', () {
      final family = {
        // claude-sonnet 家族:5(推理)与 4.6(非推理)
        'anthropic/claude-sonnet-5': {
          'name': 'New',
          'reasoning': true,
          'release_date': '2026-06-30',
        },
        'anthropic/claude-sonnet-4.6': {
          'name': 'Old',
          'reasoning': false,
          'release_date': '2026-02-17',
        },
      };
      final result = ModelCatalogService.latestPerFamily(
        ModelCatalogService.filterReasoning(family),
      );
      expect(result.keys, ['anthropic/claude-sonnet-5']);
    });
  });

  group('familyKey', () {
    test('剥代际数字:同家族版本归一键', () {
      expect(ModelCatalogService.familyKey('anthropic/claude-sonnet-5'),
          'claude-sonnet');
      expect(ModelCatalogService.familyKey('anthropic/claude-sonnet-4.6'),
          'claude-sonnet');
      expect(ModelCatalogService.familyKey('anthropic/claude-3-haiku'),
          'claude-haiku');
      expect(ModelCatalogService.familyKey('anthropic/claude-haiku-4.5'),
          'claude-haiku');
    });

    test('剥日期戳与 v 前缀版本', () {
      expect(ModelCatalogService.familyKey('deepseek/deepseek-chat-v3-0324'),
          'deepseek-chat');
      expect(ModelCatalogService.familyKey('deepseek/deepseek-chat'),
          'deepseek-chat');
      // V 线主模型同族(V3.2 与 V3 归 deepseek),留 release 最新;
      // V4-Flash/Pro 是独立规格族
      expect(ModelCatalogService.familyKey('deepseek/deepseek-v4-flash'),
          'deepseek-flash');
      expect(ModelCatalogService.familyKey('google/gemini-2.5-flash'),
          'gemini-flash');
      expect(ModelCatalogService.familyKey('google/gemini-3.6-flash'),
          'gemini-flash');
    });

    test('尺寸规格保留:不同大小视为不同家族', () {
      expect(ModelCatalogService.familyKey('qwen/qwen3-8b'), 'qwen-8b');
      expect(ModelCatalogService.familyKey('qwen/qwen3-235b-a22b'),
          'qwen-235b-a22b');
      expect(ModelCatalogService.familyKey('qwen/qwen3.5-122b-a10b'),
          'qwen-122b-a10b');
      expect(ModelCatalogService.familyKey('qwen/qwen3.6-35b-a3b'),
          'qwen-35b-a3b');
    });

    test('能力后缀保留(视觉/推理/速度变体)', () {
      expect(ModelCatalogService.familyKey('z-ai/glm-4.5v'), 'glm-v');
      expect(ModelCatalogService.familyKey('z-ai/glm-4.6v'), 'glm-v');
      expect(ModelCatalogService.familyKey('minimax/minimax-m2.5-highspeed'),
          'minimax-m-highspeed');
      expect(ModelCatalogService.familyKey('openai/gpt-5-image'), 'gpt-image');
    });

    test('实验版后缀并入主族', () {
      expect(ModelCatalogService.familyKey('deepseek/deepseek-v3.2-exp'),
          'deepseek');
      expect(ModelCatalogService.familyKey('deepseek-ai/DeepSeek-V3.2-Exp'),
          'deepseek');
      expect(ModelCatalogService.familyKey('deepseek-ai/DeepSeek-V4-Flash'),
          'deepseek-flash');
    });

    test('openrouter 规格变体(o3/o4、gpt 系列)', () {
      expect(ModelCatalogService.familyKey('openai/o3-mini'), 'o-mini');
      expect(ModelCatalogService.familyKey('openai/o4-mini'), 'o-mini');
      expect(ModelCatalogService.familyKey('openai/gpt-4.1'), 'gpt');
      expect(ModelCatalogService.familyKey('openai/gpt-5.5'), 'gpt');
      expect(ModelCatalogService.familyKey('openai/gpt-5.6-sol'), 'gpt-sol');
      expect(ModelCatalogService.familyKey('x-ai/grok-4.5'), 'grok');
    });
  });

  group('latestPerFamily', () {
    Map<String, dynamic> model(String release) =>
        {'name': 'M', if (release.isNotEmpty) 'release_date': release};

    test('同家族多版本只留 release_date 最新', () {
      final result = ModelCatalogService.latestPerFamily({
        'anthropic/claude-sonnet-4.6': model('2026-02-17'),
        'anthropic/claude-sonnet-5': model('2026-06-30'),
        'anthropic/claude-sonnet-4.5': model('2025-10-15'),
      });
      expect(result.keys, ['anthropic/claude-sonnet-5']);
    });

    test('不同家族/不同尺寸全部保留', () {
      final result = ModelCatalogService.latestPerFamily({
        'qwen/qwen3-8b': model('2025-06-01'),
        'qwen/qwen3-235b-a22b': model('2025-06-01'),
        'google/gemini-3.6-flash': model('2026-07-21'),
      });
      expect(result.keys.toSet(), {
        'qwen/qwen3-8b',
        'qwen/qwen3-235b-a22b',
        'google/gemini-3.6-flash',
      });
    });

    test('无 release_date 视为较旧', () {
      final result = ModelCatalogService.latestPerFamily({
        'deepseek/deepseek-chat-v3-0324': model('2025-03-24'),
        'deepseek/deepseek-chat': model(''), // 无日期
        'deepseek/deepseek-chat-v3.1': model(''),
      });
      expect(result.keys, ['deepseek/deepseek-chat-v3-0324']);
    });

    test('release_date 相同时保留先出现的', () {
      final result = ModelCatalogService.latestPerFamily({
        'deepseek/deepseek-v4-flash': model('2026-07-31'),
        'deepseek/deepseek-v4-flash-0731': model('2026-07-31'),
      });
      expect(result.keys, ['deepseek/deepseek-v4-flash']);
    });
  });

  group('mapModel', () {
    test('完整字段映射', () {
      final json = {
        'name': 'DeepSeek Chat',
        'limit': {'context': 1000000, 'output': 163840},
        'cost': {'input': 0.14, 'output': 0.28, 'cache_read': 0.0028},
        'reasoning': false,
        'attachment': true,
        'release_date': '2025-12-01',
      };
      final model = ModelCatalogService.mapModel(
        'deepseek-chat',
        json,
        7,
        now: DateTime(2026, 1, 1),
      );
      expect(model.name, 'DeepSeek Chat');
      expect(model.modelId, 'deepseek-chat');
      expect(model.providerId, 7);
      expect(model.contextWindow, 1000000);
      expect(model.inputPrice, r'$0.14/M input tokens');
      expect(model.outputPrice, r'$0.28/M input tokens');
      expect(model.releasedAt, 'Released 2025-12-01');
      expect(model.reasoning, isFalse);
      expect(model.vision, isTrue);
      expect(model.isPreset, isTrue);
    });

    test('缺字段时防御性兜底', () {
      final model = ModelCatalogService.mapModel(
        'bare-model',
        {'reasoning': true},
        1,
        now: DateTime(2026, 1, 1),
      );
      expect(model.name, 'bare-model'); // name 缺省用 modelId
      expect(model.contextWindow, 0);
      expect(model.inputPrice, '');
      expect(model.outputPrice, '');
      expect(model.releasedAt, '');
      expect(model.reasoning, isTrue);
      expect(model.vision, isFalse);
    });
  });

  group('isCacheFresh', () {
    test('TTL 内新鲜,超出过期', () {
      final now = DateTime(2026, 8, 1);
      expect(
        ModelCatalogService.isCacheFresh(
          now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isTrue,
      );
      expect(
        ModelCatalogService.isCacheFresh(
          now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('applyCatalog', () {
    late _FakeModelRepository modelRepo;
    late _FakeProviderRepository providerRepo;
    late _FakeChatRepository chatRepo;

    setUp(() {
      modelRepo = _FakeModelRepository();
      providerRepo = _FakeProviderRepository();
      chatRepo = _FakeChatRepository();
    });

    test('创建缺失的 provider 并插入模型', () async {
      final result = await _service(modelRepo, providerRepo, chatRepo)
          .applyCatalog(_fixtureCatalog());

      expect(providerRepo.providers, hasLength(1));
      final provider = providerRepo.providers.first;
      expect(provider.name, 'Deep Seek');
      expect(provider.baseUrl, 'https://api.deepseek.com/v1');
      expect(provider.isPreset, isTrue);

      expect(modelRepo.models, hasLength(2));
      final chat = modelRepo.models.firstWhere((m) => m.modelId == 'deepseek-chat');
      expect(chat.providerId, provider.id);
      expect(chat.contextWindow, 1000000);
      expect(chat.inputPrice, r'$0.14/M input tokens');
      expect(chat.releasedAt, 'Released 2025-12-01');
      expect(chat.vision, isTrue);

      // 统计:新增 1 provider + 2 模型
      expect(result.createdProviders, 1);
      expect(result.createdModels, 2);
      expect(result.updatedModels, 0);
      expect(result.removedModels, 0);
    });

    test('二次同步:模型更新元数据并计入统计', () async {
      final service = _service(modelRepo, providerRepo, chatRepo);
      await service.applyCatalog(_fixtureCatalog());

      final result = await service.applyCatalog(_fixtureCatalog());
      expect(result.createdProviders, 0);
      expect(result.createdModels, 0);
      expect(result.updatedModels, 2);
      expect(result.removedModels, 0);
    });

    test('已有模型更新元数据,不重复插入', () async {
      final service = _service(modelRepo, providerRepo, chatRepo);
      await service.applyCatalog(_fixtureCatalog());
      final originalId =
          modelRepo.models.firstWhere((m) => m.modelId == 'deepseek-chat').id;

      // 模拟 models.dev 更新:上下文窗口变化
      final updated = _fixtureCatalog();
      (updated['deepseek']!['models']!['deepseek-chat']!['limit']
          as Map<String, dynamic>)['context'] = 200000;

      await service.applyCatalog(updated);

      expect(modelRepo.models, hasLength(2), reason: '不应重复插入');
      final chat = modelRepo.models.firstWhere((m) => m.modelId == 'deepseek-chat');
      expect(chat.id, originalId, reason: '应更新而非重建');
      expect(chat.contextWindow, 200000);
    });

    test('白名单外且未被引用的模型被删除', () async {
      await _service(modelRepo, providerRepo, chatRepo)
          .applyCatalog(_fixtureCatalog());
      expect(modelRepo.models, hasLength(2));

      // 模拟 models.dev 下架 deepseek-chat(仅剩 reasoner)
      final slim = {
        'deepseek': {
          'models': {
            'deepseek-reasoner': _fixtureCatalog()['deepseek']!['models']!['deepseek-reasoner'],
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(slim);

      expect(modelRepo.models, hasLength(1));
      expect(modelRepo.models.single.modelId, 'deepseek-reasoner');
    });

    test('被 chat 引用的下架模型被保留', () async {
      await _service(modelRepo, providerRepo, chatRepo)
          .applyCatalog(_fixtureCatalog());
      final chatModel =
          modelRepo.models.firstWhere((m) => m.modelId == 'deepseek-chat');
      chatRepo.chatCounts[chatModel.id!] = 1;

      final slim = {
        'deepseek': {
          'models': {
            'deepseek-reasoner': _fixtureCatalog()['deepseek']!['models']!['deepseek-reasoner'],
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(slim);

      expect(modelRepo.models, hasLength(2), reason: '被引用的模型应保留');
      expect(
        modelRepo.models.map((m) => m.modelId),
        contains('deepseek-chat'),
      );
    });

    test('家族去重:同家族只插入最新版', () async {
      final catalog = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            // deepseek-chat 家族:三个版本,只应保留 release 最新
            'deepseek-chat-v3-0324': {
              'name': 'DeepSeek Chat V3',
              'release_date': '2025-03-24',
              'reasoning': true,
            },
            'deepseek-chat-v3.1': {
              'name': 'DeepSeek Chat V3.1',
              'release_date': '2025-12-01',
              'reasoning': true,
            },
            'deepseek-chat': {
              'name': 'DeepSeek Chat',
              'release_date': '2026-02-01',
              'reasoning': true,
            },
            // reasoner 独立家族,保留
            'deepseek-reasoner': {
              'name': 'DeepSeek Reasoner',
              'release_date': '2025-12-01',
              'reasoning': true,
            },
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(catalog);

      expect(modelRepo.models.map((m) => m.modelId).toSet(), {
        'deepseek-chat',
        'deepseek-reasoner',
      });
    });

    test('家族去重:被淘汰的老版本从未被 chat 引用的模型中被清理', () async {
      // 第一轮:chat 家族只有 v3-0324(唯一成员),正常入库
      final catalog = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-chat-v3-0324': {
              'name': 'Old',
              'release_date': '2025-03-24',
              'reasoning': true,
            },
          },
        },
      };
      final service = _service(modelRepo, providerRepo, chatRepo);
      await service.applyCatalog(catalog);
      expect(
        modelRepo.models.map((m) => m.modelId),
        contains('deepseek-chat-v3-0324'),
      );

      // 第二轮:同家族上架新版本 v4 → v3-0324 被家族去重淘汰
      final evolved = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-chat-v3-0324': {
              'name': 'Old',
              'release_date': '2025-03-24',
              'reasoning': true,
            },
            'deepseek-chat-v4': {
              'name': 'Newest',
              'release_date': '2026-06-01',
              'reasoning': true,
            },
          },
        },
      };
      await service.applyCatalog(evolved);

      final ids = modelRepo.models.map((m) => m.modelId).toList();
      expect(ids, contains('deepseek-chat-v4'));
      expect(ids, isNot(contains('deepseek-chat-v3-0324')),
          reason: '家族淘汰的老版本应被自动清理');
    });

    test('家族去重:被 chat 引用的老版本保留', () async {
      final catalog = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-chat-v3-0324': {
              'name': 'Old',
              'release_date': '2025-03-24',
              'reasoning': true,
            },
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(catalog);
      final oldModel =
          modelRepo.models.firstWhere((m) => m.modelId == 'deepseek-chat-v3-0324');
      chatRepo.chatCounts[oldModel.id!] = 1;

      // 新版本上架,老版本被家族去重淘汰但被 chat 引用 → 保留
      final evolved = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-chat-v3-0324': {
              'name': 'Old',
              'release_date': '2025-03-24',
              'reasoning': true,
            },
            'deepseek-chat-v4': {
              'name': 'Newest',
              'release_date': '2026-06-01',
              'reasoning': true,
            },
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(evolved);

      expect(modelRepo.models.map((m) => m.modelId).toSet(),
          containsAll(['deepseek-chat-v3-0324', 'deepseek-chat-v4']));
    });

    test('catalog 中不存在的 provider 不处理', () async {
      final noProvider = {
        'some-unknown-provider': {
          'models': {'x': {'name': 'X'}},
        },
      };
      await _service(modelRepo, providerRepo, chatRepo)
          .applyCatalog(noProvider);
      expect(providerRepo.providers, isEmpty);
      expect(modelRepo.models, isEmpty);
    });

    test('默认变体排除生效:preview/免费档/快照等被剔除', () async {
      final catalog = {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-reasoner': {
              'name': 'DeepSeek Reasoner',
              'reasoning': true,
              'release_date': '2025-05-28',
            },
            // 变体噪声:不在 include 中也能被 defaultCatalogExcludes 剔除
            'deepseek-reasoner-preview': {
              'name': 'Preview',
              'reasoning': true,
              'release_date': '2026-01-01',
            },
            'deepseek-chat:free': {
              'name': 'Free',
              'reasoning': true,
              'release_date': '2026-01-01',
            },
          },
        },
      };
      await _service(modelRepo, providerRepo, chatRepo).applyCatalog(catalog);

      expect(modelRepo.models.map((m) => m.modelId).toList(),
          ['deepseek-reasoner']);
    });
  });

  group('syncIfNeeded', () {
    late Directory tempDir;
    late String cachePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('catalog_test_');
      cachePath = '${tempDir.path}/cache.json';
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    void writeCache(Map<String, dynamic> data, DateTime fetchedAt) {
      File(cachePath).writeAsStringSync(jsonEncode({
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
        'data': data,
      }));
    }

    test('缓存新鲜时跳过拉取', () async {
      writeCache(_fixtureCatalog(), DateTime.now());
      final client = _FakeHttpClient(200, jsonEncode(_fixtureCatalog()));

      await _service(
        _FakeModelRepository(),
        _FakeProviderRepository(),
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded();

      expect(client.requestCount, 0);
    });

    test('force 时忽略 TTL 强制拉取', () async {
      writeCache(_fixtureCatalog(), DateTime.now());
      final client = _FakeHttpClient(200, jsonEncode(_fixtureCatalog()));

      final modelRepo = _FakeModelRepository();
      final providerRepo = _FakeProviderRepository();
      await _service(
        modelRepo,
        providerRepo,
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded(force: true);

      expect(client.requestCount, 1, reason: 'force 应绕过 TTL 直接拉取');
      expect(modelRepo.models, hasLength(2));
      expect(providerRepo.providers, hasLength(1));
    });

    test('缓存过期时拉取并写缓存、同步 DB', () async {
      writeCache(_fixtureCatalog(), DateTime.now().subtract(const Duration(days: 8)));
      final client = _FakeHttpClient(200, jsonEncode(_fixtureCatalog()));

      final modelRepo = _FakeModelRepository();
      final providerRepo = _FakeProviderRepository();
      await _service(
        modelRepo,
        providerRepo,
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded();

      expect(client.requestCount, 1);
      expect(modelRepo.models, hasLength(2));
      expect(providerRepo.providers, hasLength(1));

      // 缓存已刷新,再次调用应跳过
      await _service(
        modelRepo,
        providerRepo,
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded();
      expect(client.requestCount, 1);
    });

    test('拉取失败时降级用缓存数据同步', () async {
      writeCache(_fixtureCatalog(), DateTime.now().subtract(const Duration(days: 8)));
      final client = _FakeHttpClient(500, 'oops');

      final modelRepo = _FakeModelRepository();
      await _service(
        modelRepo,
        _FakeProviderRepository(),
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded();

      expect(client.requestCount, 1);
      expect(modelRepo.models, hasLength(2), reason: '应使用缓存数据同步');
    });

    test('首次拉取失败且无缓存时静默跳过', () async {
      final client = _FakeHttpClient(500, 'oops');

      final modelRepo = _FakeModelRepository();
      await _service(
        modelRepo,
        _FakeProviderRepository(),
        _FakeChatRepository(),
        httpClient: client,
        cacheFilePath: cachePath,
      ).syncIfNeeded();

      expect(modelRepo.models, isEmpty);
      // 不抛异常
    });
  });
}
