import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_gui/service/data_migration_service.dart';
import 'package:athena_gui/service/summary_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/view_model/summary_view_model.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_gui/repository/sqlite_sentinel_repository.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// 这些测试针对审计 C7：createSummary 之前使用 DateTime.now().millisecondsSinceEpoch
// 作为 int id，同毫秒创建会碰撞，导致流式写回写错记录。修复后 id 改为 String UUID。

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

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
        llmClient: LlmClient(),
        dataMigrationService: DataMigrationService(
          providerRepo: _FakeProviderRepository(),
          modelRepo: _FakeModelRepository(),
          sentinelRepo: SqliteSentinelRepository(),
          chatRepo: SqliteChatRepository(),
        ),
        agentSettings: AgentSettings(),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  SummaryViewModel buildViewModel() => SummaryViewModel(
        service: SummaryService(llmClient: LlmClient()),
        modelResolver: ModelResolver(
          modelRepo: _FakeModelRepository(),
          providerRepo: _FakeProviderRepository(),
        ),
        settingViewModel: GetIt.instance<SettingViewModel>(),
        agentService: AgentService(
          chatService: ChatCompletionsService(llmClient: LlmClient()),
          toolRegistry: ToolRegistry(),
        ),
      );

  test('C7: createSummary 生成的 id 为唯一 String（同毫秒不碰撞）', () async {
    final vm = buildViewModel();

    final ids = <String>[];
    for (var i = 0; i < 50; i++) {
      final id = await vm.createSummary('https://example.com/$i');
      expect(id, isA<String>());
      expect(id, isNotEmpty);
      ids.add(id);
    }

    expect(ids.toSet().length, ids.length, reason: 'id 必须全部唯一');
  });
}
