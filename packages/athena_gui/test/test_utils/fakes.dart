import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/repository/shortcut_repository.dart';
import 'package:athena_core/model/shortcut.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/sentinel_service.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/shortcut_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
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
  getIt.registerSingleton<ShortcutRepository>(_FakeShortcutRepository());

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

  // ViewModels（必须在 ViewModel Delegates 之前注册，因为 AgentStreamDelegate 依赖 SettingViewModel）
  getIt.registerSingleton<AgentSettings>(AgentSettings());
  getIt.registerSingleton<SettingViewModel>(
    SettingViewModel(
      modelRepository: getIt<ModelRepository>(),
      providerRepository: getIt<ProviderRepository>(),
      llmClient: getIt<LlmClient>(),
      dataMigrationService: getIt<DataMigrationService>(),
      agentSettings: getIt<AgentSettings>(),
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

  getIt.registerSingleton<ShortcutViewModel>(
    ShortcutViewModel(
      shortcutRepository: getIt<ShortcutRepository>(),
    ),
  );

  getIt.registerSingleton<ProviderViewModel>(
    ProviderViewModel(
      repository: getIt<ProviderRepository>(),
      modelViewModel: getIt<ModelViewModel>(),
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
      deps: AgentServiceCoordinatorDeps(
        agentService: getIt<AgentService>(),
        manageService: getIt<ChatManageService>(),
        messageService: getIt<ChatMessageService>(),
        chatService: getIt<ChatService>(),
        messageRepo: getIt<MessageRepository>(),
        modelRepo: getIt<ModelRepository>(),
        sentinelRepo: getIt<SentinelRepository>(),
        supportService: getIt<ChatSupportService>(),
        chatRepo: getIt<ChatRepository>(),
        agentSettings: getIt<AgentSettings>(),
        permissionService: getIt<PermissionService>(),
        skillRegistry: getIt<SkillRegistry>(),
      ),
    ),
  );

  // ChatViewModel（依赖 AgentStreamDelegate，必须在它之后）
  getIt.registerSingleton<ChatViewModel>(
    ChatViewModel(
      manageService: getIt<ChatManageService>(),
      streamDelegate: getIt<AgentStreamDelegate>(),
      renameDelegate: getIt<ChatRenameDelegate>(),
      supportService: getIt<ChatSupportService>(),
      messageRepo: getIt<MessageRepository>(),
      modelResolver: ModelResolver(
        modelRepo: getIt<ModelRepository>(),
        providerRepo: getIt<ProviderRepository>(),
      ),
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
    theme: ThemeData(
      useMaterial3: true,
      extensions: [AthenaColors.dark],
    ),
  );
}

// ---- Fake Repositories ----

class _FakeChatRepository implements ChatRepository {
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
  Future<int> recordUsage(
    int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,
  ) async => 0;
  @override
  Future<int> getChatsCount() async => 0;
  @override
  Future<int> getChatCountByModelId(int modelId) async => 0;
  @override
  Future<List<ChatEntity>> getChatsAfterId(
    int chatId, {
    int limit = 10,
  }) async => [];
  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async => [];
}

class _FakeMessageRepository implements MessageRepository {
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
  }) async => [];
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

class _FakeModelRepository implements ModelRepository {
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
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    int providerId,
  ) async => null;
  @override
  Future<void> deleteAllModels() async {}
  @override
  Future<void> importModels(List<ModelEntity> models) async {}
}

class _FakeProviderRepository implements ProviderRepository {
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
  Future<ProviderEntity?> getPresetProviderByName(String name) async => null;
  @override
  Future<void> deleteAllProviders() async {}
  @override
  Future<void> importProviders(List<ProviderEntity> providers) async {}
}

class _FakeSentinelRepository implements SentinelRepository {
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
  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}
}

class _FakeShortcutRepository implements ShortcutRepository {
  @override
  Future<List<Shortcut>> getAllShortcuts() async => [];
  @override
  Future<Shortcut?> getShortcutById(int id) async => null;
  @override
  Future<int> createShortcut(Shortcut shortcut) async => 1;
  @override
  Future<void> updateShortcut(Shortcut shortcut) async {}
  @override
  Future<void> deleteShortcut(int id) async {}
  @override
  Future<void> batchCreateShortcuts(List<Shortcut> shortcuts) async {}
  @override
  Future<Shortcut?> getShortcutBySentinelId(int sentinelId) async => null;
}
