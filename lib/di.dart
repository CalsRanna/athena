import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/file_delete_tool.dart';
import 'package:athena/agent/tool/file_read_tool.dart';
import 'package:athena/agent/tool/file_write_tool.dart';
import 'package:athena/agent/tool/search_tool.dart';
import 'package:athena/agent/tool/shell_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
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

    // Services
    getIt.registerLazySingleton(() => ChatService());
    getIt.registerLazySingleton(() => ChatMessageService());

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
    getIt.registerLazySingleton(() {
      final registry = SkillRegistry();
      registry.loadAll();
      return registry;
    });

    getIt.registerLazySingleton(() {
      final skillRegistry = getIt<SkillRegistry>();
      final toolRegistry = ToolRegistry()
        ..registerAll([
          SearchTool(),
          FileReadTool(),
          FileWriteTool(),
          FileDeleteTool(),
          ShellTool(),
          SkillTool(skillRegistry),
        ]);
      return toolRegistry;
    });

    getIt.registerLazySingleton(() => AgentService(
      toolRegistry: getIt<ToolRegistry>(),
    ));
  }
}
