import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_gui/service/data_migration_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/service/sentinel_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/storage/shared_prefs_key_value_store.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:get_it/get_it.dart';

class DI {
  /// 用户级数据根目录的父目录:桌面端是 `$HOME`(与 TUI 共享
  /// `~/.athena/`);移动端无可靠 `$HOME`,用 Application Support
  /// ([dataDirectory])。写入端(skill_evolve / experience 工具)必须与
  /// 这里读同一目录。
  static String _homeDir(String? dataDirectory) {
    if (PlatformUtil.isMobile && dataDirectory != null) return dataDirectory;
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
  }

  static void ensureInitialized({String? dataDirectory}) {
    final getIt = GetIt.instance;

    // 文件持久化(布局见 FileStorage):root = $HOME/.athena
    final storage = FileStorage(
      root: Directory('${_homeDir(dataDirectory)}/.athena'),
    );
    getIt.registerSingleton<FileStorage>(storage);

    getIt.registerLazySingleton(
      () => ToolOutputStore(directory: storage.toolOutputsDir),
    );

    // Repositories (no dependencies)
    _registerRepositories(storage, dataDirectory);

    // Services
    _registerServices();

    // ViewModel Delegates
    getIt.registerLazySingleton(
      () => ChatRenameDelegate(
        messageRepo: getIt<MessageRepository>(),
        modelRepo: getIt<ModelRepository>(),
        supportService: getIt<ChatUpdateService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => AgentStreamDelegate(
        deps: AgentServiceCoordinatorDeps(
          agentService: getIt<AgentService>(),
          manageService: getIt<ChatStoreService>(),
          messageService: getIt<ChatMessageConverter>(),
          chatService: getIt<ChatCompletionsService>(),
          messageRepo: getIt<MessageRepository>(),
          modelRepo: getIt<ModelRepository>(),
          sentinelRepo: getIt<SentinelRepository>(),
          chatRepo: getIt<ChatRepository>(),
          supportService: getIt<ChatUpdateService>(),
          agentSettings: getIt<AgentSettings>(),
          permissionService: getIt<PermissionService>(),
          experienceRepository: getIt<ExperienceRepository>(),
        ),
      ),
    );

    // ViewModels
    getIt.registerLazySingleton(
      () => ModelViewModel(
        repository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatService: getIt<ChatCompletionsService>(),
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
        storage: getIt<FileStorage>(),
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
      () => SkillViewModel(skillRegistry: getIt<SkillRegistry>()),
    );

    getIt.registerLazySingleton(
      () => ExperienceViewModel(
        experienceRepository: getIt<ExperienceRepository>(),
        sentinelRepository: getIt<SentinelRepository>(),
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

    getIt.registerLazySingleton(() {
      final registry = SkillRegistry();
      // 移动端无可靠 $HOME，用户级数据根目录用 Application Support（与
      // FileStorage 同根）；写入端（skill_evolve / experience 工具）必须与
      // 这里读同一目录。
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
        outputStore: getIt<ToolOutputStore>(),
        onSentinelChanged: () => getIt<SentinelViewModel>().getSentinels(),
        mobileHomeDir: dataDirectory,
      ),
    );

    getIt.registerLazySingleton(
      () => AgentService(
        chatService: getIt<ChatCompletionsService>(),
        toolRegistry: getIt<ToolRegistry>(),
        skillRegistry: getIt<SkillRegistry>(),
      ),
    );

    // ChatViewModel (depends on many things, registered last)
    getIt.registerLazySingleton(
      () => ChatViewModel(
        manageService: getIt<ChatStoreService>(),
        streamDelegate: getIt<AgentStreamDelegate>(),
        renameDelegate: getIt<ChatRenameDelegate>(),
        supportService: getIt<ChatUpdateService>(),
        messageRepo: getIt<MessageRepository>(),
        modelResolver: getIt<ModelResolver>(),
        settingViewModel: getIt<SettingViewModel>(),
        modelViewModel: getIt<ModelViewModel>(),
        sentinelViewModel: getIt<SentinelViewModel>(),
      ),
    );
  }

  static void _registerRepositories(
    FileStorage storage,
    String? dataDirectory,
  ) {
    final getIt = GetIt.instance;
    // 同一实例同时承担 ChatRepository 与 MessageRepository:对话与其消息
    // 同生命周期,删对话即删会话文件
    getIt.registerLazySingleton<ChatRepository>(
      () => storage.sessionRepository,
    );
    getIt.registerLazySingleton<MessageRepository>(
      () => storage.sessionRepository,
    );
    getIt.registerLazySingleton<ModelRepository>(
      () => storage.modelRepository,
    );
    getIt.registerLazySingleton<ProviderRepository>(
      () => storage.providerRepository,
    );
    getIt.registerLazySingleton<SentinelRepository>(
      () => storage.sentinelRepository,
    );
    getIt.registerLazySingleton(
      () => ExperienceRepository(
        homeDir: PlatformUtil.isMobile ? dataDirectory : null,
      ),
    );
  }

  static void _registerServices() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton(() => LlmClient());

    getIt.registerLazySingleton(
      () => ChatCompletionsService(llmClient: getIt<LlmClient>()),
    );

    getIt.registerLazySingleton(
      () => ChatMessageConverter(
        messageRepository: getIt<MessageRepository>(),
        outputStore: getIt<ToolOutputStore>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ChatStoreService(
        chatRepository: getIt<ChatRepository>(),
        messageRepository: getIt<MessageRepository>(),
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        sentinelRepository: getIt<SentinelRepository>(),
      ),
    );

    getIt.registerLazySingleton(
      () => ChatUpdateService(
        chatRepository: getIt<ChatRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatService: getIt<ChatCompletionsService>(),
      ),
    );

    getIt.registerLazySingleton(
      () => SentinelService(llmClient: getIt<LlmClient>()),
    );

    getIt.registerLazySingleton(
      () => DataMigrationService(
        providerRepo: getIt<ProviderRepository>(),
        modelRepo: getIt<ModelRepository>(),
        sentinelRepo: getIt<SentinelRepository>(),
        chatRepo: getIt<ChatRepository>(),
      ),
    );

    // 目录缓存放数据目录(与 TUI 共享),不用 systemTemp:重启清空临时
    // 目录后不必每次重新拉取 3.2MB
    getIt.registerLazySingleton(
      () => ModelCatalogService(
        modelRepository: getIt<ModelRepository>(),
        providerRepository: getIt<ProviderRepository>(),
        chatRepository: getIt<ChatRepository>(),
        cacheFilePath: getIt<FileStorage>().catalogCacheFile.path,
      ),
    );
  }
}
