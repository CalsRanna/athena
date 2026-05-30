import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/file_delete_tool.dart';
import 'package:athena/agent/tool/file_update_tool.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/file_write_tool.dart';
import 'package:athena/agent/tool/web_fetch_tool.dart';
import 'package:athena/agent/tool/web_search_tool.dart';
import 'package:athena/agent/tool/list_directory_tool.dart';
import 'dart:io';
import 'package:athena/agent/tool/bash_shell_tool.dart';
import 'package:athena/agent/tool/powershell_shell_tool.dart';
import 'package:athena/agent/tool/unix_search_tool.dart';
import 'package:athena/agent/tool/powershell_search_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';
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
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/view_model/summary_view_model.dart';

import 'package:athena/view_model/translation_view_model.dart';
import 'package:athena/view_model/trpg_view_model.dart';
import 'package:athena/view_model/memory_view_model.dart';
import 'package:get_it/get_it.dart';

class DI {
  static void ensureInitialized() {
    final getIt = GetIt.instance;

    // Repositories
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
    getIt.registerLazySingleton(() => ChatMessageService());
    getIt.registerLazySingleton(() => ChatManageService());
    getIt.registerLazySingleton(() => ChatSupportService());
    getIt.registerLazySingleton(() => MemoryService());
    getIt.registerLazySingleton(() => SentinelService());
    getIt.registerLazySingleton(() => SummaryService());
    getIt.registerLazySingleton(() => TranslationService());
    getIt.registerLazySingleton(() => TRPGService());

    // ViewModels
    getIt.registerLazySingleton(() => ChatViewModel());
    getIt.registerLazySingleton(() => ModelViewModel());
    getIt.registerLazySingleton(() => ProviderViewModel());
    getIt.registerLazySingleton(() => SentinelViewModel());
    getIt.registerLazySingleton(() => SettingViewModel());
    getIt.registerLazySingleton(() => TranslationViewModel());
    getIt.registerLazySingleton(() => SummaryViewModel());
    getIt.registerLazySingleton(() => TRPGViewModel());
    getIt.registerLazySingleton(() => MemoryViewModel());

    // Agent
    getIt.registerLazySingleton(() => PathSandbox());
    getIt.registerLazySingleton(() => PermissionStore());
    getIt.registerLazySingleton(
      () => PermissionService(
        store: getIt<PermissionStore>(),
        sandbox: getIt<PathSandbox>(),
      ),
    );

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
      toolRegistry: getIt<ToolRegistry>(),
      skillRegistry: getIt<SkillRegistry>(),
    ));
  }
}
