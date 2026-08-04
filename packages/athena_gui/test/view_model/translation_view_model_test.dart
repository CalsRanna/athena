import 'dart:async';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/translation_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/translation_service.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/view_model/translation_view_model.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

// 这些测试针对审计 C5：performTranslation 在流式期间从未更新 translatedText 信号，
// 导致翻译面板在整段响应到达前一直空白。修复后应在每个 chunk 后实时更新信号。
//
// 方案：注入伪 AgentService 产出可控的 AgentTextEvent 流；伪 Provider/Model
// 仓库返回固定的启用 provider 与模型；通过 GetIt 注册 SettingViewModel
// （performTranslation 体内直接经 GetIt 解析），并在 tearDown 中 reset。

ModelEntity _model() => ModelEntity(
      id: 1,
      name: 'm',
      modelId: 'm',
      providerId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

ProviderEntity _provider() => ProviderEntity(
      id: 1,
      name: 'p',
      baseUrl: 'http://localhost',
      apiKey: 'k',
      enabled: true,
      createdAt: DateTime(2024),
    );

/// 伪 Agent 服务：将外部提供的 [stream] 原样返回，便于控制 chunk 时序。
class _FakeAgentService extends AgentService {
  _FakeAgentService(this.stream)
    : super(
        chatService: ChatService(llmClient: LlmClient()),
        toolRegistry: ToolRegistry(),
      );

  final Stream<AgentEvent> stream;

  @override
  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
    bool jsonMode = false,
  }) =>
      stream;
}

class _FakeProviderRepository extends ProviderRepository {
  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [_provider()];

  @override
  Future<ProviderEntity?> getProviderById(int id) async => _provider();

  @override
  Future<int> storeProvider(ProviderEntity provider) async => 0;

  @override
  Future<void> updateProvider(ProviderEntity provider) async {}

  @override
  Future<void> deleteProvider(int id) async {}

  @override
  Future<int> getProvidersCount() async => 0;

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) async {}

  @override
  Future<ProviderEntity?> getProviderByName(String name) async => null;

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async => null;

  @override
  Future<void> deleteAllProviders() async {}

  @override
  Future<void> importProviders(List<ProviderEntity> providers) async {}

  @override
  Future<List<ProviderEntity>> getAllProviders() async => [];
}

class _FakeModelRepository extends ModelRepository {
  @override
  Future<ModelEntity?> getModelById(int id) async => _model();

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async =>
      [_model()];

  @override
  Future<int> createModel(ModelEntity model) async => 0;

  @override
  Future<void> updateModel(ModelEntity model) async {}

  @override
  Future<void> deleteModel(int id) async {}

  @override
  Future<void> deleteModelsByProviderId(int providerId) async {}

  @override
  Future<int> getModelsCount() async => 0;

  @override
  Future<void> batchCreateModels(List<ModelEntity> models) async {}

  @override
  Future<ModelEntity?> getModelByNameAndProviderId(String name,
    int providerId,) async => null;

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(String modelId,
    int providerId,) async => null;

  @override
  Future<void> deleteAllModels() async {}

  @override
  Future<void> importModels(List<ModelEntity> models) async {}

  @override
  Future<List<ModelEntity>> getAllModels() async => [];
}

class _FakeSentinelRepository extends SentinelRepository {
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;

  @override
  Future<int> createSentinel(SentinelEntity sentinel) async => 0;

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {}

  @override
  Future<void> deleteSentinel(int id) async {}

  @override
  Future<int> getSentinelsCount() async => 0;

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {}

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async => null;

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}

  @override
  Future<List<SentinelEntity>> getAllSentinels() async => [];
}

TranslationEntity _translation() => TranslationEntity(
      id: 'fixed-id',
      source: 'en',
      sourceText: 'hello',
      target: 'zh',
      targetText: '',
      createdAt: DateTime(2024),
    );

void main() {
  setUp(() {
    GetIt.instance.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
        llmClient: LlmClient(),
        dataMigrationService: DataMigrationService(
          providerRepo: _FakeProviderRepository(),
          modelRepo: _FakeModelRepository(),
          sentinelRepo: _FakeSentinelRepository(),
          chatRepo: SqliteChatRepository(),
        ),
        agentSettings: AgentSettings(),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test('C5: performTranslation 流式期间逐步更新 translatedText 信号', () async {
    // 每发出一段文本后等待一个 gate，测试在中途断言信号已增长。
    final gate1 = Completer<void>();
    final gate2 = Completer<void>();
    final emittedFirst = Completer<void>();
    final emittedSecond = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield AgentEvent.text('你好');
      if (!emittedFirst.isCompleted) emittedFirst.complete();
      await gate1.future;
      yield AgentEvent.text('，世界');
      if (!emittedSecond.isCompleted) emittedSecond.complete();
      await gate2.future;
    }

    final vm = TranslationViewModel(
      settingViewModel: GetIt.instance<SettingViewModel>(),
      service: TranslationService(llmClient: LlmClient()),
      agentService: _FakeAgentService(events()),


      modelResolver: ModelResolver(modelRepo: _FakeModelRepository(), providerRepo: _FakeProviderRepository()),
    );

    final future = vm.performTranslation(_translation());

    // 第一段到达后：信号应已非空且等于首段。
    await emittedFirst.future;
    expect(vm.translatedText.value, '你好',
        reason: '流式中途信号必须已更新，而非保持空白');
    gate1.complete();

    // 第二段到达后：信号应等于两段拼接。
    await emittedSecond.future;
    expect(vm.translatedText.value, '你好，世界');
    gate2.complete();

    await future;

    // 结束后信号等于完整拼接。
    expect(vm.translatedText.value, '你好，世界');
  });

  test('C5: performTranslation 完成后将完整译文写回 translations 列表', () async {
    Stream<AgentEvent> events() async* {
      yield AgentEvent.text('你好');
      yield AgentEvent.text('，世界');
    }

    final vm = TranslationViewModel(
      settingViewModel: GetIt.instance<SettingViewModel>(),
      service: TranslationService(llmClient: LlmClient()),
      agentService: _FakeAgentService(events()),


      modelResolver: ModelResolver(modelRepo: _FakeModelRepository(), providerRepo: _FakeProviderRepository()),
    );

    // 先经 createTranslation 将占位记录放入列表（模拟真实调用顺序）。
    final id = await vm.createTranslation('en', 'hello', 'zh');
    final translation = vm.translations.value.firstWhere((t) => t.id == id);

    await vm.performTranslation(translation);

    final stored = vm.translations.value.firstWhere((t) => t.id == id);
    expect(stored.targetText, '你好，世界');
  });

  test('C7: createTranslation 生成的 id 为唯一 String（同毫秒不碰撞）', () async {
    final vm = TranslationViewModel(
      settingViewModel: GetIt.instance<SettingViewModel>(),
      service: TranslationService(llmClient: LlmClient()),
      agentService: _FakeAgentService(const Stream.empty()),


      modelResolver: ModelResolver(modelRepo: _FakeModelRepository(), providerRepo: _FakeProviderRepository()),
    );

    final ids = <String>[];
    for (var i = 0; i < 50; i++) {
      final id = await vm.createTranslation('en', 'hello $i', 'zh');
      expect(id, isA<String>());
      expect(id, isNotEmpty);
      ids.add(id);
    }

    expect(ids.toSet().length, ids.length, reason: 'id 必须全部唯一');
  });

  test('C7: 两条记录并存时写回正确记录（无 id 碰撞误写）', () async {
    Stream<AgentEvent> events() async* {
      yield AgentEvent.text('world');
    }

    final vm = TranslationViewModel(
      settingViewModel: GetIt.instance<SettingViewModel>(),
      service: TranslationService(llmClient: LlmClient()),
      agentService: _FakeAgentService(events()),


      modelResolver: ModelResolver(modelRepo: _FakeModelRepository(), providerRepo: _FakeProviderRepository()),
    );

    // 创建两条记录（真实场景可能同毫秒创建）。
    final idA = await vm.createTranslation('en', 'A', 'zh');
    final idB = await vm.createTranslation('en', 'B', 'zh');
    expect(idA, isNot(idB));

    final translationB =
        vm.translations.value.firstWhere((t) => t.id == idB);
    await vm.performTranslation(translationB);

    final storedB = vm.translations.value.firstWhere((t) => t.id == idB);
    final storedA = vm.translations.value.firstWhere((t) => t.id == idA);
    expect(storedB.targetText, 'world', reason: '译文应写回目标记录 B');
    expect(storedA.targetText, '', reason: '另一条记录 A 不应被误写');
  });
}
