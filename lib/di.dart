import 'package:athena/view_model/ai_provider_view_model.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/view_model/summary_view_model.dart';
import 'package:athena/view_model/tool_view_model.dart';
import 'package:athena/view_model/translation_view_model.dart';
import 'package:get_it/get_it.dart';

class DI {
  static void ensureInitialized() {
    final getIt = GetIt.instance;

    // 只注册 ViewModels - Factory (每个页面新实例)
    // ViewModel 内部直接持有 Service/Repository 实例

    // 核心 ViewModels
    getIt.registerFactory(() => ChatViewModel());
    getIt.registerFactory(() => ModelViewModel());
    getIt.registerFactory(() => AIProviderViewModel());
    getIt.registerFactory(() => SentinelViewModel());
    getIt.registerFactory(() => ToolViewModel());
    getIt.registerFactory(() => ServerViewModel());
    getIt.registerFactory(() => SettingViewModel());
    getIt.registerFactory(() => TranslationViewModel());
    getIt.registerFactory(() => SummaryViewModel());
  }
}
