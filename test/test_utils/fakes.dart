import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/llm_client.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/service/data_migration_service.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 注册移动端 widget 测试所需的最小化 DI 依赖。
///
/// 所有 repository 使用内存 fake（不访问真实数据库），
/// 所有 service / viewModel 使用真实实例但信号初始为空。
/// 调用方可在测试中直接设置 signal 值来模拟数据。
void setupMobileTestDI() {
  final getIt = GetIt.instance;

  // Reset any previous registrations
  getIt.reset();

  // Fake repositories (in-memory, no database access)
  getIt.registerSingleton<ChatRepository>(_FakeChatRepository());
  getIt.registerSingleton<MessageRepository>(_FakeMessageRepository());
  getIt.registerSingleton<ModelRepository>(_FakeModelRepository());
  getIt.registerSingleton<ProviderRepository>(_FakeProviderRepository());
  getIt.registerSingleton<SentinelRepository>(_FakeSentinelRepository());

  // Services
  getIt.registerSingleton<LlmClient>(LlmClient());

  getIt.registerSingleton<DataMigrationService>(
    DataMigrationService(
      providerRepo: getIt<ProviderRepository>(),
      modelRepo: getIt<ModelRepository>(),
      sentinelRepo: getIt<SentinelRepository>(),
      chatRepo: getIt<ChatRepository>(),
    ),
  );

  getIt.registerSingleton<ChatService>(
    ChatService(llmClient: getIt<LlmClient>()),
  );

  getIt.registerSingleton<ChatMessageService>(
    ChatMessageService(messageRepository: getIt<MessageRepository>()),
  );

  getIt.registerSingleton<ChatManageService>(
    ChatManageService(
      chatRepository: getIt<ChatRepository>(),
      messageRepository: getIt<MessageRepository>(),
      modelRepository: getIt<ModelRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      sentinelRepository: getIt<SentinelRepository>(),
    ),
  );

  getIt.registerSingleton<ChatSupportService>(
    ChatSupportService(
      chatRepository: getIt<ChatRepository>(),
      messageRepository: getIt<MessageRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      chatService: getIt<ChatService>(),
    ),
  );

  getIt.registerSingleton<SentinelService>(
    SentinelService(llmClient: getIt<LlmClient>()),
  );

  // Agent
  getIt.registerSingleton<PermissionService>(
    PermissionService(store: PermissionStore()),
  );
  getIt.registerSingleton<SkillRegistry>(
    SkillRegistry(trustStore: SkillTrustStore()),
  );
  getIt.registerSingleton<ToolRegistry>(ToolRegistry());
  getIt.registerSingleton<AgentService>(
    AgentService(
      chatService: getIt<ChatService>(),
      toolRegistry: getIt<ToolRegistry>(),
      skillRegistry: getIt<SkillRegistry>(),
    ),
  );

  // ViewModel Delegates
  getIt.registerSingleton<ChatRenameDelegate>(
    ChatRenameDelegate(
      messageRepo: getIt<MessageRepository>(),
      modelRepo: getIt<ModelRepository>(),
      supportService: getIt<ChatSupportService>(),
    ),
  );

  getIt.registerSingleton<AgentStreamDelegate>(
    AgentStreamDelegate(
      agentService: getIt<AgentService>(),
      manageService: getIt<ChatManageService>(),
      messageService: getIt<ChatMessageService>(),
      chatService: getIt<ChatService>(),
      messageRepo: getIt<MessageRepository>(),
      modelRepo: getIt<ModelRepository>(),
      sentinelRepo: getIt<SentinelRepository>(),
      supportService: getIt<ChatSupportService>(),
      settingViewModel: getIt<SettingViewModel>(),
      permissionService: getIt<PermissionService>(),
      skillRegistry: getIt<SkillRegistry>(),
    ),
  );

  // ViewModels
  getIt.registerSingleton<SettingViewModel>(
    SettingViewModel(
      modelRepository: getIt<ModelRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      llmClient: getIt<LlmClient>(),
      dataMigrationService: getIt<DataMigrationService>(),
    ),
  );

  getIt.registerSingleton<ModelViewModel>(
    ModelViewModel(
      repository: getIt<ModelRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      chatService: getIt<ChatService>(),
    ),
  );

  getIt.registerSingleton<SentinelViewModel>(
    SentinelViewModel(
      sentinelRepository: getIt<SentinelRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      modelRepository: getIt<ModelRepository>(),
      sentinelService: getIt<SentinelService>(),
    ),
  );

  getIt.registerSingleton<ProviderViewModel>(
    ProviderViewModel(
      repository: getIt<ProviderRepository>(),
      modelViewModel: getIt<ModelViewModel>(),
    ),
  );

  getIt.registerSingleton<ChatViewModel>(
    ChatViewModel(
      manageService: getIt<ChatManageService>(),
      streamDelegate: getIt<AgentStreamDelegate>(),
      renameDelegate: getIt<ChatRenameDelegate>(),
      supportService: getIt<ChatSupportService>(),
      messageRepo: getIt<MessageRepository>(),
      settingViewModel: getIt<SettingViewModel>(),
      modelViewModel: getIt<ModelViewModel>(),
      sentinelViewModel: getIt<SentinelViewModel>(),
    ),
  );
}

/// 快速创建一个 Sentinel 用于测试。
SentinelEntity testSentinel({
  int id = 1,
  String name = 'Athena',
  String description = 'A friendly chat assistant.',
  String prompt = 'You are a helpful assistant.',
}) {
  return SentinelEntity(
    id: id,
    name: name,
    description: description,
    prompt: prompt,
    avatar: '',
    tags: '',
  );
}

/// 快速创建一个 Chat 用于测试。
ChatEntity testChat({
  int id = 1,
  String title = 'Test Chat',
  int sentinelId = 1,
  int modelId = 1,
  int retention = -1,
  double temperature = 1.0,
}) {
  return ChatEntity(
    id: id,
    title: title,
    sentinelId: sentinelId,
    modelId: modelId,
    retention: retention,
    temperature: temperature,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

/// 快速创建一个 Model 用于测试。
ModelEntity testModel({
  int id = 1,
  String name = 'Test Model',
  String modelId = 'gpt-4',
  int providerId = 1,
}) {
  return ModelEntity(
    id: id,
    name: name,
    modelId: modelId,
    providerId: providerId,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

/// 最小 MaterialApp 包装，用于 widget 测试。
Widget wrapWithApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
    theme: ThemeData(useMaterial3: true),
  );
}

// ---- Fake Repositories ----

class _FakeChatRepository extends ChatRepository {
  @override
  Future<List<ChatEntity>> getAllChats() async => [];
  @override
  Future<ChatEntity?> getChatById(int id) async => null;
  @override
  Future<int> createChat(ChatEntity chat) async => 1;
  @override
  Future<void> updateChat(ChatEntity chat) async {}
  @override
  Future<void> deleteChat(int id) async {}
  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async => [];
  @override
  Future<int> getChatsCount() async => 0;
  @override
  Future<List<ChatEntity>> getChatsAfterId(
    int chatId, {
    int limit = 10,
  }) async => [];
  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async => [];
}

class _FakeMessageRepository extends MessageRepository {
  @override
  Future<int> storeMessage(MessageEntity message) async => 1;
  @override
  Future<void> updateMessage(MessageEntity message) async {}
  @override
  Future<void> markAsCompacted(Set<int> ids) async {}
  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async =>
      [];
  @override
  Future<MessageEntity?> getMessageById(int id) async => null;
  @override
  Future<void> deleteMessage(int id) async {}
  @override
  Future<void> deleteMessagesByChatId(int chatId) async {}
  @override
  Future<int> getMessagesCount(int chatId) async => 0;
  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async => null;
}

class _FakeModelRepository extends ModelRepository {
  @override
  Future<List<ModelEntity>> getAllModels() async => [];
  @override
  Future<ModelEntity?> getModelById(int id) async => null;
  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async => [];
  @override
  Future<int> createModel(ModelEntity model) async => 1;
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
  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    int providerId,
  ) async => null;
  @override
  Future<void> deleteAllModels() async {}
}

class _FakeProviderRepository extends ProviderRepository {
  @override
  Future<List<ProviderEntity>> getAllProviders() async => [];
  @override
  Future<ProviderEntity?> getProviderById(int id) async => null;
  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [];
  @override
  Future<int> storeProvider(ProviderEntity provider) async => 1;
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
  Future<void> deleteAllProviders() async {}
}

class _FakeSentinelRepository extends SentinelRepository {
  @override
  Future<List<SentinelEntity>> getAllSentinels() async => [];
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;
  @override
  Future<int> createSentinel(SentinelEntity sentinel) async => 1;
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
}
