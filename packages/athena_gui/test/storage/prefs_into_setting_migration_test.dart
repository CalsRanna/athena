import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_gui/storage/prefs_into_setting_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 旧 SharedPreferences 偏好 → `setting.yaml` 的一次性搬运。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late UserSettingsStore settings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_prefs_migration_');
    settings = UserSettingsStore(
      file: File(p.join(tmp.path, 'setting.yaml')),
      locks: LockRegistry(tmp),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  test('各类型按原类型落到 setting.yaml，源键被移除', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'text_size': 'large',
      'window_width': 1200.5,
      'max_retries': 3,
      'background_task_reports': false,
      'brave_api_key': 'sk-abc',
    });

    await const PrefsIntoSettingMigration().run(settings);

    expect(await settings.getString('theme_mode'), 'dark');
    expect(await settings.getString('text_size'), 'large');
    expect(await settings.getDouble('window_width'), 1200.5);
    expect(await settings.getInt('max_retries'), 3);
    expect(await settings.getBool('background_task_reports'), false);
    expect(await settings.loadBraveApiKey(), 'sk-abc');

    final prefs = await SharedPreferences.getInstance();
    for (final key in PrefsIntoSettingMigration.keys) {
      expect(prefs.get(key), isNull, reason: '$key 应已从 prefs 移除');
    }
  });

  test('旧整数模型 id 保留为 int，UUID 替换链路才认得出', () async {
    SharedPreferences.setMockInitialValues({'chat_model_id': 3});

    await const PrefsIntoSettingMigration().run(settings);

    expect(await settings.get('chat_model_id'), 3);
    expect(await settings.get('chat_model_id'), isA<int>());
  });

  test('AgentSettings 的键一并搬运', () async {
    SharedPreferences.setMockInitialValues({
      'background_task_reports': true,
      'approval_mode': 'manual',
      'ai_approval_enabled': 0,
    });

    await const PrefsIntoSettingMigration().run(settings);

    expect(await settings.getBool('background_task_reports'), true);
    expect(await settings.getString('approval_mode'), 'manual');
    expect(await settings.getInt('ai_approval_enabled'), 0);
  });

  test('setting.yaml 已有同名键时以文件为准', () async {
    await settings.setString('theme_mode', 'light');
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

    await const PrefsIntoSettingMigration().run(settings);

    expect(await settings.getString('theme_mode'), 'light');
    // 以文件为准，但 prefs 里的遗留值仍然清掉，不留无主数据
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('theme_mode'), isNull);
  });

  test('没有遗留值时不动 setting.yaml', () async {
    SharedPreferences.setMockInitialValues({});
    await settings.setString('theme_mode', 'light');
    final before = await File(p.join(tmp.path, 'setting.yaml')).readAsString();

    await const PrefsIntoSettingMigration().run(settings);

    expect(await File(p.join(tmp.path, 'setting.yaml')).readAsString(), before);
  });

  test('跑两次结果一致（源键已清空，第二次无事发生）', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

    await const PrefsIntoSettingMigration().run(settings);
    final after = await File(p.join(tmp.path, 'setting.yaml')).readAsString();
    await const PrefsIntoSettingMigration().run(settings);

    expect(await File(p.join(tmp.path, 'setting.yaml')).readAsString(), after);
    expect(await settings.getString('theme_mode'), 'dark');
  });

  test('清单里不含与别的插件共用的键', () async {
    // 拿不准的键宁可留在 prefs 里，也不要替别的插件做决定
    expect(PrefsIntoSettingMigration.keys, isNotEmpty);
    expect(PrefsIntoSettingMigration.keys, isNot(contains('flutter.language')));
  });
}
