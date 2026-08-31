import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/sentinel_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

// 新建对话的角色选择规则：
// 默认使用 Athena（不复用 currentSentinel 中残留的上一个对话角色）；
// 仅草稿态显式选定（含 Shortcut 入口注入）时使用选定角色，且一次性消费。

void main() {
  late _RecordingChatRepository chatRepo;
  late SentinelViewModel sentinelViewModel;
  late ChatViewModel viewModel;

  final athena = SentinelEntity(id: 1, name: 'Athena', prompt: 'p');
  final custom = SentinelEntity(id: 2, name: 'Custom', prompt: 'p');

  setUp(() {
    chatRepo = _RecordingChatRepository();
    sentinelViewModel = SentinelViewModel(
      sentinelRepository: _FakeSentinelRepository(),
      providerRepository: _FakeProviderRepository(),
      modelRepository: _FakeModelRepository(),
      sentinelService: SentinelService(llmClient: LlmClient()),
    );
    final manageService = ChatManageService(
      chatRepository: chatRepo,
      messageRepository: _FakeMessageRepository(),
      modelRepository: _FakeModelRepository(),
      providerRepository: _FakeProviderRepository(),
      sentinelRepository: _FakeSentinelRepository(),
    );
    final supportService = ChatSupportService(
      chatRepository: chatRepo,
      messageRepository: _FakeMessageRepository(),
      providerRepository: _FakeProviderRepository(),
      chatService: ChatService(llmClient: LlmClient()),
    );
    viewModel = ChatViewModel(
      manageService: manageService,
      streamDelegate: AgentStreamDelegate(
        deps: AgentServiceCoordinatorDeps(
          agentService: AgentService(
            chatService: ChatService(llmClient: LlmClient()),
            toolRegistry: ToolRegistry(),
          ),
          manageService: manageService,
          chatService: ChatService(llmClient: LlmClient()),
          messageService: ChatMessageService(
            messageRepository: _FakeMessageRepository(),
          ),
          messageRepo: _FakeMessageRepository(),
          modelRepo: _FakeModelRepository(),
          sentinelRepo: _FakeSentinelRepository(),
          chatRepo: chatRepo,
          supportService: supportService,
          agentSettings: AgentSettings(),
          permissionService: PermissionService(store: PermissionStore()),
        ),
      ),
      renameDelegate: ChatRenameDelegate(
        messageRepo: _FakeMessageRepository(),
        modelRepo: _FakeModelRepository(),
        supportService: supportService,
      ),
      supportService: supportService,
      messageRepo: _FakeMessageRepository(),
      modelResolver: ModelResolver(
        modelRepo: _FakeModelRepository(),
        providerRepo: _FakeProviderRepository(),
      ),
      settingViewModel: SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
        llmClient: LlmClient(),
        dataMigrationService: DataMigrationService(
          providerRepo: _FakeProviderRepository(),
          modelRepo: _FakeModelRepository(),
          sentinelRepo: _FakeSentinelRepository(),
          chatRepo: chatRepo,
        ),
        agentSettings: AgentSettings(),
      ),
      modelViewModel: ModelViewModel(
        repository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
        chatService: ChatService(llmClient: LlmClient()),
      ),
      sentinelViewModel: sentinelViewModel,
    );
  });

  group('ChatViewModel.createChat sentinel selection', () {
    test('defaults to Athena when previous chat left a sentinel behind',
        () async {
      sentinelViewModel.sentinels.value = [athena, custom];
      // 模拟正在查看上一个对话：currentSentinel 残留其角色。
      viewModel.currentSentinel.value = custom;

      await viewModel.createChat();

      expect(chatRepo.createdChats.single.sentinelId, athena.id);
    });

    test('uses the draft sentinel when explicitly chosen', () async {
      sentinelViewModel.sentinels.value = [athena, custom];
      viewModel.currentSentinel.value = custom;

      // 草稿态显式选择（Shortcut 入口注入亦走此路径）。
      viewModel.updateCurrentSentinel(custom);
      await viewModel.createChat();

      expect(chatRepo.createdChats.single.sentinelId, custom.id);
    });

    test('draft sentinel is consumed once', () async {
      sentinelViewModel.sentinels.value = [athena, custom];

      viewModel.updateCurrentSentinel(custom);
      await viewModel.createChat();
      expect(chatRepo.createdChats.single.sentinelId, custom.id);
      expect(viewModel.draftSentinel.value, isNull);

      // 下一次新建对话不再复用已消费的草稿角色。
      await viewModel.createChat();
      expect(chatRepo.createdChats.last.sentinelId, athena.id);
    });
  });
}

/// 记录 createChat 收到的实体，供断言 sentinelId。
class _RecordingChatRepository extends ChatRepository {
  final List<ChatEntity> createdChats = [];

  @override
  Future<int> createChat(ChatEntity chat) async {
    createdChats.add(chat);
    return createdChats.length;
  }

  @override
  Future<List<ChatEntity>> getAllChats() async => [];

  @override
  Future<ChatEntity?> getChatById(int id) async => null;

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
  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10}) async =>
      [];

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

class _FakeModelRepository extends ModelRepository {
  @override
  Future<List<ModelEntity>> getAllModels() async => [_model];

  @override
  Future<ModelEntity?> getModelById(int id) async => _model;

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async =>
      [_model];

  @override
  Future<int> createModel(ModelEntity model) async => 1;

  @override
  Future<void> updateModel(ModelEntity model) async {}

  @override
  Future<void> deleteModel(int id) async {}

  @override
  Future<void> deleteModelsByProviderId(int providerId) async {}

  @override
  Future<int> getModelsCount() async => 1;

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

  static final _model = ModelEntity(
    id: 1,
    name: 'm',
    modelId: 'm',
    providerId: 1,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

class _FakeProviderRepository extends ProviderRepository {
  @override
  Future<List<ProviderEntity>> getAllProviders() async => [_provider];

  @override
  Future<ProviderEntity?> getProviderById(int id) async => _provider;

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [_provider];

  @override
  Future<int> storeProvider(ProviderEntity provider) async => 1;

  @override
  Future<void> updateProvider(ProviderEntity provider) async {}

  @override
  Future<void> deleteProvider(int id) async {}

  @override
  Future<int> getProvidersCount() async => 1;

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

  static final _provider = ProviderEntity(
    id: 1,
    name: 'p',
    baseUrl: 'http://localhost',
    apiKey: 'k',
    createdAt: DateTime(2024),
  );
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

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}
}
