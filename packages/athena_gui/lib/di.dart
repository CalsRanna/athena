import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/repository/sqlite_message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_gui/repository/sqlite_model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_gui/repository/sqlite_provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_gui/repository/sqlite_sentinel_repository.dart';
import 'package:athena_core/repository/shortcut_repository.dart';
import 'package:athena_gui/repository/sqlite_shortcut_repository.dart';
import 'package:athena_core/repository/trpg_game_repository.dart';
import 'package:athena_gui/repository/sqlite_trpg_game_repository.dart';
import 'package:athena_core/repository/trpg_message_repository.dart';
import 'package:athena_gui/repository/sqlite_trpg_message_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/sentinel_service.dart';
import 'package:athena_core/service/summary_service.dart';
import 'package:athena_core/service/translation_service.dart';
import 'package:athena_core/service/trpg_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/storage/shared_prefs_key_value_store.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/view_model/shortcut_view_model.dart';
import 'package:athena_gui/view_model/summary_view_model.dart';
import 'package:athena_gui/view_model/translation_view_model.dart';
import 'package:athena_gui/view_model/trpg_view_model.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

class DI {
  static void ensureInitialized({String? dataDirectory}) {
    final getIt = GetIt.instance;

    // Repositories (no dependencies)
    _registerRepositories(dataDirectory);

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
        deps: AgentServiceCoordinatorDeps(
          agentService: getIt<AgentService>(),
          manageService: getIt<ChatManageService>(),
          messageService: getIt<ChatMessageService>(),
          chatService: getIt<ChatService>(),
          messageRepo: getIt<MessageRepository>(),
          modelRepo: getIt<ModelRepository>(),
          sentinelRepo: getIt<SentinelRepository>(),
          chatRepo: getIt<ChatRepository>(),
          supportService: getIt<ChatSupportService>(),
          agentSettings: getIt<AgentSettings>(),
          permissionService: getIt<PermissionService>(),
          skillRegistry: getIt<SkillRegistry>(),
        ),
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
        agentSettings: getIt<AgentSettings>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ProviderViewModel(
        repository: getIt<ProviderRepository>(),
        modelViewModel: getIt<ModelViewModel>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ShortcutViewModel(
        shortcutRepository: getIt<ShortcutRepository>(),
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
        agentService: getIt<AgentService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TranslationViewModel(
        service: getIt<TranslationService>(),
        modelResolver: getIt<ModelResolver>(),
        settingViewModel: getIt<SettingViewModel>(),
        agentService: getIt<AgentService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => TRPGViewModel(
        gameRepository: getIt<TRPGGameRepository>(),
        messageRepository: getIt<TRPGMessageRepository>(),
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        settingViewModel: getIt<SettingViewModel>(),
        modelResolver: getIt<ModelResolver>(),
        agentService: getIt<AgentService>(),
      ),
    );

    // Agent
    getIt.registerLazySingleton(() => PermissionStore());
    getIt.registerLazySingleton(
      () => PermissionService(store: getIt<PermissionStore>()),
    );

    // 键值存储（核心接口，GUI 用 SharedPreferences 实现）
    getIt.registerLazySingleton<KeyValueStore>(
      () => SharedPrefsKeyValueStore(),
    );

    // Agent 设置（核心，持久化走 KeyValueStore）
    getIt.registerLazySingleton(
      () => AgentSettings(store: getIt<KeyValueStore>()),
    );

    getIt.registerLazySingleton(() => SkillTrustStore());
    getIt.registerLazySingleton(() {
      final registry = SkillRegistry(trustStore: getIt<SkillTrustStore>());
      // 移动端无可靠 $HOME，进化数据根目录用 Application Support（与 athena.db 同根）；
      // 写入端（skill_evolve / experience 工具）必须与这里读同一目录，
      // reloadSkill 才能把写的技能归类为用户级而不是项目级 pending。
      registry.loadAll(homeDir: PlatformUtil.isMobile ? dataDirectory : null);
      registry.registerBuiltin(kSelfEvolveSkill);
      return registry;
    });

    // 工具清单是引擎的事实，统一在 athena_core 的 buildToolRegistry 里；
    // 这里只提供 GUI 特有的差异项。
    getIt.registerLazySingleton(
      () => buildToolRegistry(
        skillRegistry: getIt<SkillRegistry>(),
        experienceRepository: getIt<ExperienceRepository>(),
        sentinelRepository: getIt<SentinelRepository>(),
        store: getIt<KeyValueStore>(),
        onSentinelChanged: () => getIt<SentinelViewModel>().getSentinels(),
        mobileHomeDir: dataDirectory,
      ),
    );

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

  static void _registerRepositories(String? dataDirectory) {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<ChatRepository>(() => SqliteChatRepository());
    getIt.registerLazySingleton<MessageRepository>(
      () => SqliteMessageRepository(),
    );
    getIt.registerLazySingleton<ModelRepository>(() => SqliteModelRepository());
    getIt.registerLazySingleton<ProviderRepository>(
      () => SqliteProviderRepository(),
    );
    getIt.registerLazySingleton<SentinelRepository>(
      () => SqliteSentinelRepository(),
    );
    getIt.registerLazySingleton(
      () => ExperienceRepository(
        homeDir: PlatformUtil.isMobile ? dataDirectory : null,
      ),
    );
    getIt.registerLazySingleton<TRPGGameRepository>(
      () => SqliteTRPGGameRepository(),
    );
    getIt.registerLazySingleton<TRPGMessageRepository>(
      () => SqliteTRPGMessageRepository(),
    );
    getIt.registerLazySingleton<ShortcutRepository>(
      () => SqliteShortcutRepository(),
    );
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
        mobileExportDirProvider: getApplicationDocumentsDirectory,
        downloadsDirProvider: getDownloadsDirectory,
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
      () => ModelCatalogService(
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatRepository: getIt<ChatRepository>(),
      ),
    );
  }
}
