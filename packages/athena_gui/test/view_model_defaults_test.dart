import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_gui/repository/sqlite_message_repository.dart';
import 'package:athena_gui/repository/sqlite_model_repository.dart';
import 'package:athena_gui/repository/sqlite_provider_repository.dart';
import 'package:athena_gui/repository/sqlite_sentinel_repository.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_gui/service/data_migration_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/service/sentinel_service.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  setUpAll(() {
    DI.ensureInitialized();
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  group('SentinelViewModel.defaultSentinel', () {
    test('falls back to Athena when no sentinels are loaded', () {
      final viewModel = SentinelViewModel(
        sentinelRepository: SqliteSentinelRepository(),
        providerRepository: SqliteProviderRepository(),
        modelRepository: SqliteModelRepository(),
        sentinelService: SentinelService(llmClient: LlmClient()),
      );

      final sentinel = viewModel.defaultSentinel.value;

      expect(sentinel.name, 'Athena');
      expect(sentinel.prompt, isNotEmpty);
    });

    test('prefers the stored Athena sentinel when available', () {
      final viewModel = SentinelViewModel(
        sentinelRepository: SqliteSentinelRepository(),
        providerRepository: SqliteProviderRepository(),
        modelRepository: SqliteModelRepository(),
        sentinelService: SentinelService(llmClient: LlmClient()),
      );
      final storedAthena = SentinelEntity(
        id: 2,
        name: 'Athena',
        prompt: 'stored prompt',
      );

      viewModel.sentinels.value = [
        SentinelEntity(id: 1, name: 'Custom'),
        storedAthena,
      ];

      expect(viewModel.defaultSentinel.value.id, storedAthena.id);
      expect(viewModel.defaultSentinel.value.prompt, 'stored prompt');
    });
  });

  group('ChatViewModel draft defaults', () {
    test('start from the shared new chat defaults', () {
      final manageService = ChatStoreService(
            chatRepository: SqliteChatRepository(),
            messageRepository: SqliteMessageRepository(),
            modelRepository: SqliteModelRepository(),
            providerRepository: SqliteProviderRepository(),
            sentinelRepository: SqliteSentinelRepository(),
          );
      final supportService = ChatUpdateService(
            chatRepository: SqliteChatRepository(),
            messageRepository: SqliteMessageRepository(),
            providerRepository: SqliteProviderRepository(),
            chatService: ChatCompletionsService(llmClient: LlmClient()),
          );
      final viewModel = ChatViewModel(
        manageService: manageService,
        streamDelegate: AgentStreamDelegate(
          deps: AgentServiceCoordinatorDeps(
            agentService: AgentService(
              chatService: ChatCompletionsService(llmClient: LlmClient()),
              toolRegistry: ToolRegistry(),
            ),
            manageService: manageService,
            chatService: ChatCompletionsService(llmClient: LlmClient()),
            messageService: ChatMessageConverter(
              messageRepository: SqliteMessageRepository(),
            ),
            messageRepo: SqliteMessageRepository(),
            modelRepo: SqliteModelRepository(),
            sentinelRepo: SqliteSentinelRepository(),
            chatRepo: SqliteChatRepository(),
            supportService: supportService,
            agentSettings: AgentSettings(),
            permissionService: PermissionService(store: PermissionStore()),
            experienceRepository: ExperienceRepository(
              homeDir: Directory.systemTemp.path,
            ),
          ),
        ),
        renameDelegate: ChatRenameDelegate(
          messageRepo: SqliteMessageRepository(),
          modelRepo: SqliteModelRepository(),
          supportService: supportService,
        ),
        supportService: supportService,
        messageRepo: SqliteMessageRepository(),
        modelResolver: ModelResolver(
          modelRepo: SqliteModelRepository(),
          providerRepo: SqliteProviderRepository(),
        ),
        settingViewModel: SettingViewModel(
          modelRepository: SqliteModelRepository(),
          providerRepository: SqliteProviderRepository(),
          llmClient: LlmClient(),
          dataMigrationService: DataMigrationService(
            providerRepo: SqliteProviderRepository(),
            modelRepo: SqliteModelRepository(),
            sentinelRepo: SqliteSentinelRepository(),
            chatRepo: SqliteChatRepository(),
          ),
          agentSettings: AgentSettings(),
        ),
        modelViewModel: ModelViewModel(
          repository: SqliteModelRepository(),
          providerRepository: SqliteProviderRepository(),
          chatService: ChatCompletionsService(llmClient: LlmClient()),
        ),
        sentinelViewModel: SentinelViewModel(
          sentinelRepository: SqliteSentinelRepository(),
          providerRepository: SqliteProviderRepository(),
          modelRepository: SqliteModelRepository(),
          sentinelService: SentinelService(llmClient: LlmClient()),
        ),
      );

      expect(viewModel.currentRetention.value, ChatViewModel.defaultDraftRetention);
      expect(
        viewModel.currentTemperature.value,
        ChatViewModel.defaultDraftTemperature,
      );
      expect(
        viewModel.currentReasoningEffort.value,
        isNull,
        reason: '默认不传 reasoning_effort，使用模型默认强度',
      );
    });
  });
}
