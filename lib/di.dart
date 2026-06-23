import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/evolution/evolution_prompt.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/bash_shell_tool.dart';
import 'package:athena/agent/tool/experience_learn_tool.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/file_update_tool.dart';
import 'package:athena/agent/tool/file_write_tool.dart';
import 'package:athena/agent/tool/powershell_shell_tool.dart';
import 'package:athena/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena/agent/tool/skill_evolve_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/agent/tool/web_fetch_tool.dart';
import 'package:athena/agent/tool/web_search_tool.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/experience_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/repository/trpg_game_repository.dart';
import 'package:athena/repository/trpg_message_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/service/data_migration_service.dart';
import 'package:athena/service/llm_client.dart';
import 'package:athena/service/model_resolver.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/service/summary_service.dart';
import 'package:athena/service/translation_service.dart';
import 'package:athena/service/trpg_service.dart';
import 'package:athena/service/token_usage_service.dart';
import 'package:athena/util/platform_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/view_model/summary_view_model.dart';
import 'package:athena/view_model/translation_view_model.dart';
import 'package:athena/view_model/trpg_view_model.dart';
import 'package:get_it/get_it.dart';

class DI {
  static void ensureInitialized({String? dataDirectory}) {
    final getIt = GetIt.instance;

    // Repositories (no dependencies)
    _registerRepositories();

    // Services
    _registerServices();

    // ViewModel Delegates
    getIt.registerLazySingleton(
      () => ChatRenameDelegate(
        messageRepo: getIt<MessageRepository>(),
        modelRepo: getIt<ModelRepository>(),
        supportService: getIt<ChatSupportService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => AgentStreamDelegate(
        agentService: getIt<AgentService>(),
        manageService: getIt<ChatManageService>(),
        messageService: getIt<ChatMessageService>(),
        chatService: getIt<ChatService>(),
        messageRepo: getIt<MessageRepository>(),
        modelRepo: getIt<ModelRepository>(),
        sentinelRepo: getIt<SentinelRepository>(),
        supportService: getIt<ChatSupportService>(),
        tokenUsageService: getIt<TokenUsageService>(),
        settingViewModel: getIt<SettingViewModel>(),
        permissionService: getIt<PermissionService>(),
        skillRegistry: getIt<SkillRegistry>(),
      ),
    );

    // ViewModels
    getIt.registerLazySingleton(
      () => ModelViewModel(
        repository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatService: getIt<ChatService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SentinelViewModel(
        sentinelRepository: getIt<SentinelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        modelRepository: getIt<ModelRepository>(),
        sentinelService: getIt<SentinelService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SettingViewModel(
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        llmClient: getIt<LlmClient>(),
        dataMigrationService: getIt<DataMigrationService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ProviderViewModel(
        repository: getIt<ProviderRepository>(),
        modelViewModel: getIt<ModelViewModel>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ModelResolver(
        modelRepo: getIt<ModelRepository>(),
        providerRepo: getIt<ProviderRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SummaryViewModel(
        service: getIt<SummaryService>(),
        modelResolver: getIt<ModelResolver>(),
        settingViewModel: getIt<SettingViewModel>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TranslationViewModel(
        service: getIt<TranslationService>(),
        modelResolver: getIt<ModelResolver>(),
        settingViewModel: getIt<SettingViewModel>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TRPGViewModel(
        gameRepository: getIt<TRPGGameRepository>(),
        messageRepository: getIt<TRPGMessageRepository>(),
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        service: getIt<TRPGService>(),
        settingViewModel: getIt<SettingViewModel>(),
        modelResolver: getIt<ModelResolver>(),
      ),
    );

    // Agent
    getIt.registerLazySingleton(() => PermissionStore());
    getIt.registerLazySingleton(
      () => PermissionService(store: getIt<PermissionStore>()),
    );

    getIt.registerLazySingleton(() => SkillTrustStore());
    getIt.registerLazySingleton(() {
      final registry = SkillRegistry(trustStore: getIt<SkillTrustStore>());
      registry.loadAll();
      registry.registerBuiltin(
        const Skill(
          name: 'self-evolve',
          description:
              'Guidance on self-evolution: creating skills, recording '
              'experiences, and optimizing sentinels to improve over time',
          body: EvolutionPrompt.fullBody,
          sourcePath: '(builtin)',
        ),
      );
      return registry;
    });

    getIt.registerLazySingleton(() {
      final skillRegistry = getIt<SkillRegistry>();
      final experienceRepository = getIt<ExperienceRepository>();
      final isWindows = PlatformUtil.isWindows;
      final isMobile = PlatformUtil.isMobile;
      final toolRegistry = ToolRegistry();

      if (isMobile) {
        toolRegistry.registerAll([
          WebFetchTool(),
          WebSearchTool(),
          SkillTool(skillRegistry),
        ]);
      } else {
        toolRegistry.registerAll([
          FileReadTool(),
          FileWriteTool(),
          FileUpdateTool(),
          isWindows ? PowerShellShellTool() : BashShellTool(),
          WebFetchTool(),
          WebSearchTool(),
          SkillTool(skillRegistry),
          SkillEvolveTool(skillRegistry: skillRegistry),
          ExperienceLearnTool(repository: experienceRepository),
          ExperienceRecallTool(repository: experienceRepository),
          SentinelEvolveTool(
            repository: getIt<SentinelRepository>(),
            onChanged: () => getIt<SentinelViewModel>().getSentinels(),
          ),
        ]);
      }

      return toolRegistry;
    });

    getIt.registerLazySingleton(
      () => AgentService(
        chatService: getIt<ChatService>(),
        toolRegistry: getIt<ToolRegistry>(),
        skillRegistry: getIt<SkillRegistry>(),
      ),
    );

    // ChatViewModel (depends on many things, registered last)
    getIt.registerLazySingleton(
      () => ChatViewModel(
        manageService: getIt<ChatManageService>(),
        streamDelegate: getIt<AgentStreamDelegate>(),
        renameDelegate: getIt<ChatRenameDelegate>(),
        supportService: getIt<ChatSupportService>(),
        messageRepo: getIt<MessageRepository>(),
        modelResolver: getIt<ModelResolver>(),
        settingViewModel: getIt<SettingViewModel>(),
        modelViewModel: getIt<ModelViewModel>(),
        sentinelViewModel: getIt<SentinelViewModel>(),
      ),
    );
  }

  static void _registerRepositories() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton(() => ChatRepository());
    getIt.registerLazySingleton(() => MessageRepository());
    getIt.registerLazySingleton(() => ModelRepository());
    getIt.registerLazySingleton(() => ProviderRepository());
    getIt.registerLazySingleton(() => SentinelRepository());
    getIt.registerLazySingleton(() => ExperienceRepository());
    getIt.registerLazySingleton(() => TRPGGameRepository());
    getIt.registerLazySingleton(() => TRPGMessageRepository());
  }

  static void _registerServices() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton(() => LlmClient());

    getIt.registerLazySingleton(
      () => ChatService(llmClient: getIt<LlmClient>()),
    );

    getIt.registerLazySingleton(
      () => ChatMessageService(messageRepository: getIt<MessageRepository>()),
    );

    getIt.registerLazySingleton(
      () => ChatManageService(
        chatRepository: getIt<ChatRepository>(),
        messageRepository: getIt<MessageRepository>(),
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        sentinelRepository: getIt<SentinelRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ChatSupportService(
        chatRepository: getIt<ChatRepository>(),
        messageRepository: getIt<MessageRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatService: getIt<ChatService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SentinelService(llmClient: getIt<LlmClient>()),
    );
    getIt.registerLazySingleton(
      () => SummaryService(llmClient: getIt<LlmClient>()),
    );
    getIt.registerLazySingleton(
      () => TranslationService(llmClient: getIt<LlmClient>()),
    );
    getIt.registerLazySingleton(
      () => TRPGService(llmClient: getIt<LlmClient>()),
    );

    getIt.registerLazySingleton(
      () => DataMigrationService(
        providerRepo: getIt<ProviderRepository>(),
        modelRepo: getIt<ModelRepository>(),
        sentinelRepo: getIt<SentinelRepository>(),
        chatRepo: getIt<ChatRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TokenUsageService(chatRepo: getIt<ChatRepository>()),
    );
  }
}
