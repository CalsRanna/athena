import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一次性升级：把 GUI 留在 SharedPreferences 里的偏好搬进 `setting.yaml`。
///
/// 此前 GUI 的设置在 SharedPreferences、TUI 的在 `~/.athena/kv.json`、core 的
/// 混合在两者之间，同一种东西三处存放。搬完之后 `setting.yaml` 是唯一落点，
/// SharedPreferences 只剩本文件这一个使用者（`pubspec.yaml` 里的依赖保留，就
/// 是为了不让升级用户的偏好丢失）。
///
/// **保留原始类型**，不统一转成字符串：GUI 更早的版本把模型 id 存成整数，
/// `SettingViewModel` 靠 `is int` 认出它们再换成 UUID（见 [UserSettingsStore.get]）。
/// 这里若转成 `"3"`，那条替换逻辑就永远不会触发，用户的默认模型会静默失效。
///
/// 幂等靠「搬完就删源键」实现，不需要版本标记：重跑时源键已不存在，无事发生。
/// 用 [SharedPreferences.remove] 而不是 `clear()`——虽然插件侧的 `clear` 带
/// `flutter.` 前缀过滤（`shared_preferences_foundation` 的 `clear(prefix:)`），
/// 逐个删与本处「显式清单」的口径一致，也不受前缀约定变化影响。
class PrefsIntoSettingMigration {
  const PrefsIntoSettingMigration();

  /// 需要搬运的全部键。
  ///
  /// 比「GUI 自己的偏好」长：`AgentSettings` 的键今天也是经
  /// `SharedPrefsKeyValueStore` 落在 SharedPreferences 里的，漏掉就会丢掉
  /// 用户的 Max iterations / 后台汇报开关。
  static const keys = <String>[
    // GUI 直接读写
    'window_height',
    'window_width',
    'chat_model_id',
    'chat_naming_model_id',
    'sentinel_metadata_generation_model_id',
    'max_retries',
    'brave_api_key',
    'theme_mode',
    'text_size',
    // 经 AgentSettings
    'max_agent_iterations',
    'background_task_reports',
    // 更早的全局审批设置：AgentSettings 读到就删，必须一起搬，
    // 否则新会话的审批档位会退回默认而不是用户设过的值
    'approval_mode',
    'ai_approval_enabled',
  ];

  Future<void> run(UserSettingsStore settings) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // 插件不可用（如纯 Dart 测试宿主）不该挡住启动
      LoggerUtil.w('SharedPreferences unavailable, skipped settings migration');
      return;
    }

    var moved = 0;
    for (final key in keys) {
      final value = prefs.get(key);
      if (value == null) continue;
      // 文件是权威来源，prefs 只是遗留：已有同名键时以文件为准
      if (await settings.get(key) == null) {
        await settings.set(key, value);
        moved++;
      }
      await prefs.remove(key);
    }
    if (moved > 0) {
      LoggerUtil.i('Settings: migrated $moved preference(s) to setting.yaml');
    }
  }
}
