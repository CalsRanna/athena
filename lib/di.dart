import 'package:athena/page/desktop/home/home_view_model.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/repository/server_repository.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/view_model/summary_view_model.dart';
import 'package:athena/view_model/tool_view_model.dart';
import 'package:athena/view_model/translation_view_model.dart';
import 'package:athena/view_model/trpg_view_model.dart';
import 'package:get_it/get_it.dart';

class DI {
  static void ensureInitialized() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton(() => ChatViewModel());
    getIt.registerLazySingleton(() => ModelViewModel());
    getIt.registerLazySingleton(() => ProviderViewModel());
    getIt.registerLazySingleton(() => SentinelViewModel());
    getIt.registerLazySingleton(() => ToolViewModel());
    getIt.registerLazySingleton(() => ServerViewModel());
    getIt.registerLazySingleton(() => SettingViewModel());
    getIt.registerLazySingleton(() => TranslationViewModel());
    getIt.registerLazySingleton(() => SummaryViewModel());
    getIt.registerLazySingleton(() => TRPGViewModel());

    getIt.registerLazySingleton(() => HomeViewModel());
  }
}
