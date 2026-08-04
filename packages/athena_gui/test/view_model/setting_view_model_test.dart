import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';

// 这些测试针对审计 C6：importData 从其他实例导入数据后，本地 chats 表中的
// model_id 可能指向已不存在的模型（chats 无外键约束），使用该会话会触发
// 'Model not found'。修复方案：导入后扫描 chats，将悬空的 model_id 重置为
// 合理的默认模型。这里直接测试 reconcileChatModelReferences()。

ModelEntity _model(int id) => ModelEntity(
      id: id,
      name: 'm$id',
      modelId: 'm$id',
      providerId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

ChatEntity _chat({required int id, required int modelId}) => ChatEntity(
      id: id,
      title: 'chat $id',
      modelId: modelId,
      sentinelId: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// 伪 ModelRepository：返回受控的模型列表。
class _FakeModelRepository extends ModelRepository {
  _FakeModelRepository(this.models);

  final List<ModelEntity> models;

  @override
  Future<List<ModelEntity>> getAllModels() async => models;

  @override
  Future<ModelEntity?> getModelById(int id) async => null;

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
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async => [];
}

/// 伪 ChatRepository：内存中保存 chats，记录 updateChat 调用以便断言。
class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository(this.chats);

  final List<ChatEntity> chats;
  final List<int> updatedChatIds = [];

  @override
  Future<List<ChatEntity>> getAllChats() async => List.of(chats);

  @override
  Future<void> updateChat(ChatEntity chat) async {
    updatedChatIds.add(chat.id!);
    final index = chats.indexWhere((c) => c.id == chat.id);
    if (index != -1) chats[index] = chat;
  }

  @override
  Future<ChatEntity?> getChatById(int id) async => null;

  @override
  Future<int> createChat(ChatEntity chat) async => 0;

  @override
  Future<void> deleteChat(int id) async {}

  @override
  Future<int> recordUsage(int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,) async => 0;

  @override
  Future<int> getChatsCount() async => 0;

  @override
  Future<int> getChatCountByModelId(int modelId) async => 0;

  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async => [];

  @override
  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10}) async => [];

  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async => [];
}

class _FakeProviderRepository extends ProviderRepository {
  @override
  Future<ProviderEntity?> getProviderById(int id) async => null;

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

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [];
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

SettingViewModel _vm({
  required List<ModelEntity> models,
  required _FakeChatRepository chatRepository,
}) {
  final modelRepo = _FakeModelRepository(models);
  return SettingViewModel(
    modelRepository: modelRepo,
    providerRepository: _FakeProviderRepository(),
    llmClient: LlmClient(),
    dataMigrationService: DataMigrationService(
      providerRepo: _FakeProviderRepository(),
      modelRepo: modelRepo,
      sentinelRepo: _FakeSentinelRepository(),
      chatRepo: chatRepository,
    ),
    agentSettings: AgentSettings(),
  );
}

void main() {
  test('C6: 悬空的 model_id 被重置为有效的 chatModelId', () async {
    final chat = _chat(id: 100, modelId: 999); // 999 不存在
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [_model(1), _model(2)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 2; // 有效的默认模型

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, [100]);
    expect(chatRepo.chats.single.modelId, 2);
  });

  test('C6: 当 chatModelId 本身无效时，重置为第一个可用模型', () async {
    final chat = _chat(id: 100, modelId: 999); // 999 不存在
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [_model(5), _model(6)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 0; // 默认且无效

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, [100]);
    expect(chatRepo.chats.single.modelId, 5); // 第一个可用模型
  });

  test('C6: 有效 model_id 的会话不被修改', () async {
    final validChat = _chat(id: 100, modelId: 1);
    final danglingChat = _chat(id: 200, modelId: 999);
    final chatRepo = _FakeChatRepository([validChat, danglingChat]);
    final vm = _vm(
      models: [_model(1), _model(2)],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 2;

    await vm.reconcileChatModelReferences();

    // 仅悬空会话被更新；有效会话保持不变。
    expect(chatRepo.updatedChatIds, [200]);
    final stillValid = chatRepo.chats.firstWhere((c) => c.id == 100);
    expect(stillValid.modelId, 1);
    final fixed = chatRepo.chats.firstWhere((c) => c.id == 200);
    expect(fixed.modelId, 2);
  });

  test('C6: 没有任何模型时不执行任何操作且不抛出', () async {
    final chat = _chat(id: 100, modelId: 999);
    final chatRepo = _FakeChatRepository([chat]);
    final vm = _vm(
      models: [],
      chatRepository: chatRepo,
    );
    vm.chatModelId.value = 0;

    await vm.reconcileChatModelReferences();

    expect(chatRepo.updatedChatIds, isEmpty);
    expect(chatRepo.chats.single.modelId, 999); // 保持原样
  });
}
