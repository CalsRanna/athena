import 'dart:io';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_interactor.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/bash_shell_tool.dart';
import 'package:athena/agent/tool/file_delete_tool.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/file_update_tool.dart';
import 'package:athena/agent/tool/file_write_tool.dart';
import 'package:athena/agent/tool/list_directory_tool.dart';
import 'package:athena/agent/tool/powershell_search_tool.dart';
import 'package:athena/agent/tool/powershell_shell_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/agent/tool/unix_search_tool.dart';
import 'package:athena/agent/tool/web_fetch_tool.dart';
import 'package:athena/agent/tool/web_search_tool.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/memory_repository.dart';
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
import 'package:athena/service/memory_service.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/service/summary_service.dart';
import 'package:athena/service/translation_service.dart';
import 'package:athena/service/trpg_service.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/memory_view_model.dart';
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
    getIt.registerLazySingleton(() => ChatRepository());
    getIt.registerLazySingleton(() => MessageRepository());
    getIt.registerLazySingleton(() => ModelRepository());
    getIt.registerLazySingleton(() => ProviderRepository());
    getIt.registerLazySingleton(() => SentinelRepository());
    getIt.registerLazySingleton(() => MemoryRepository());
    getIt.registerLazySingleton(() => TRPGGameRepository());
    getIt.registerLazySingleton(() => TRPGMessageRepository());

    // Services
    getIt.registerLazySingleton(() => ChatService());

    getIt.registerLazySingleton(() => ChatMessageService(
          messageRepository: getIt<MessageRepository>(),
        ));

    getIt.registerLazySingleton(() => ChatManageService(
          chatRepository: getIt<ChatRepository>(),
          messageRepository: getIt<MessageRepository>(),
          modelRepository: getIt<ModelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          sentinelRepository: getIt<SentinelRepository>(),
        ));

    getIt.registerLazySingleton(() => ChatSupportService(
          chatRepository: getIt<ChatRepository>(),
          messageRepository: getIt<MessageRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          chatService: getIt<ChatService>(),
        ));

    getIt.registerLazySingleton(() => MemoryService());
    getIt.registerLazySingleton(() => SentinelService());
    getIt.registerLazySingleton(() => SummaryService());
    getIt.registerLazySingleton(() => TranslationService());
    getIt.registerLazySingleton(() => TRPGService());

    // ViewModels
    getIt.registerLazySingleton(() => ModelViewModel(
          repository: getIt<ModelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          chatService: getIt<ChatService>(),
        ));

    getIt.registerLazySingleton(() => SentinelViewModel(
          sentinelRepository: getIt<SentinelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          modelRepository: getIt<ModelRepository>(),
          sentinelService: getIt<SentinelService>(),
        ));

    getIt.registerLazySingleton(() => SettingViewModel(
          modelRepository: getIt<ModelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          sentinelRepository: getIt<SentinelRepository>(),
          chatRepository: getIt<ChatRepository>(),
          chatService: getIt<ChatService>(),
        ));

    getIt.registerLazySingleton(() => ProviderViewModel(
          repository: getIt<ProviderRepository>(),
          modelViewModel: getIt<ModelViewModel>(),
        ));

    getIt.registerLazySingleton(() => SummaryViewModel(
          service: getIt<SummaryService>(),
          modelRepository: getIt<ModelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          settingViewModel: getIt<SettingViewModel>(),
        ));

    getIt.registerLazySingleton(() => TranslationViewModel(
          service: getIt<TranslationService>(),
          providerRepository: getIt<ProviderRepository>(),
          modelRepository: getIt<ModelRepository>(),
          settingViewModel: getIt<SettingViewModel>(),
        ));

    getIt.registerLazySingleton(() => TRPGViewModel(
          gameRepository: getIt<TRPGGameRepository>(),
          messageRepository: getIt<TRPGMessageRepository>(),
          modelRepository: getIt<ModelRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          service: getIt<TRPGService>(),
          settingViewModel: getIt<SettingViewModel>(),
        ));

    getIt.registerLazySingleton(() => MemoryViewModel(
          memoryRepository: getIt<MemoryRepository>(),
          chatRepository: getIt<ChatRepository>(),
          messageRepository: getIt<MessageRepository>(),
          providerRepository: getIt<ProviderRepository>(),
          memoryService: getIt<MemoryService>(),
        ));

    // Agent
    getIt.registerLazySingleton(() => PathSandbox(dataDirectory: dataDirectory));
    getIt.registerLazySingleton(() => PermissionStore());
    getIt.registerLazySingleton(() => PermissionService(
          store: getIt<PermissionStore>(),
          sandbox: getIt<PathSandbox>(),
        ));

    getIt.registerLazySingleton(() => SkillTrustStore());
    getIt.registerLazySingleton(() {
      final registry = SkillRegistry(trustStore: getIt<SkillTrustStore>());
      registry.loadAll();
      return registry;
    });

    getIt.registerLazySingleton(() {
      final skillRegistry = getIt<SkillRegistry>();
      final sandbox = getIt<PathSandbox>();
      final isWindows = Platform.isWindows;
      final toolRegistry = ToolRegistry()
        ..registerAll([
          isWindows
              ? PowerShellSearchTool(sandbox: sandbox)
              : UnixSearchTool(sandbox: sandbox),
          FileReadTool(sandbox: sandbox),
          FileWriteTool(sandbox: sandbox),
          FileUpdateTool(sandbox: sandbox),
          FileDeleteTool(sandbox: sandbox),
          ListDirectoryTool(sandbox: sandbox),
          isWindows
              ? PowerShellShellTool(sandbox: sandbox)
              : BashShellTool(sandbox: sandbox),
          WebFetchTool(),
          WebSearchTool(),
          SkillTool(skillRegistry),
        ]);
      return toolRegistry;
    });

    getIt.registerLazySingleton(() => AgentService(
          chatService: getIt<ChatService>(),
          toolRegistry: getIt<ToolRegistry>(),
          skillRegistry: getIt<SkillRegistry>(),
        ));

    getIt.registerLazySingleton(() => PermissionInteractor(
          permissionService: getIt<PermissionService>(),
        ));

    // ChatViewModel (depends on many things, registered last)
    getIt.registerLazySingleton(() => ChatViewModel(
          manageService: getIt<ChatManageService>(),
          supportService: getIt<ChatSupportService>(),
          chatMessageService: getIt<ChatMessageService>(),
          agentService: getIt<AgentService>(),
          messageRepository: getIt<MessageRepository>(),
          modelRepository: getIt<ModelRepository>(),
          sentinelRepository: getIt<SentinelRepository>(),
          settingViewModel: getIt<SettingViewModel>(),
          modelViewModel: getIt<ModelViewModel>(),
          sentinelViewModel: getIt<SentinelViewModel>(),
          permissionService: getIt<PermissionService>(),
          skillRegistry: getIt<SkillRegistry>(),
          permissionInteractor: getIt<PermissionInteractor>(),
        ));
  }
}
