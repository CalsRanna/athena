import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `~/.athena/setting.yaml` 的共同存储契约。
///
/// 重点在「两个前端共用同一个文件」带来的两条要求：写一端的键不能抹掉另一
/// 端的键；两个实例指向同一文件时不能互相覆盖。
void main() {
  late Directory tmp;
  late File file;
  late UserSettingsStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_settings_');
    file = File(p.join(tmp.path, 'setting.yaml'));
    store = UserSettingsStore(file: file);
  });

  tearDown(() => tmp.delete(recursive: true));

  List<File> backupsOf(File target) => target.parent
      .listSync()
      .whereType<File>()
      .where(
        (f) => p
            .basename(f.path)
            .startsWith('${p.basename(target.path)}.corrupt-'),
      )
      .toList();

  group('标量往返', () {
    test('各类型写入后按原类型读回', () async {
      await store.setString('theme_mode', 'dark');
      await store.setInt('max_retries', 3);
      await store.setBool('background_task_reports', false);
      await store.setDouble('window_height', 812.5);

      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getInt('max_retries'), 3);
      expect(await store.getBool('background_task_reports'), false);
      expect(await store.getDouble('window_height'), 812.5);
    });

    test('不存在的键返回 null，而不是默认值', () async {
      expect(await store.getString('nope'), isNull);
      expect(await store.getInt('nope'), isNull);
      expect(await store.getBool('nope'), isNull);
      expect(await store.getDouble('nope'), isNull);
      expect(await store.get('nope'), isNull);
    });

    test('数字形状的字符串被读成数字，bool 不会', () async {
      // YAML 手工编辑容易写出不加引号的标量，读时按数值口径容错
      await file.writeAsString('window_height: "812"\n');
      expect(await store.getDouble('window_height'), 812.0);

      // background_task_reports 的默认是 true，所以「键不存在」必须与 false
      // 可区分：只有真的是 false 才返回 false
      await file.writeAsString('background_task_reports: false\n');
      expect(await store.getBool('background_task_reports'), false);
      await file.writeAsString('other: false\n');
      expect(await store.getBool('background_task_reports'), isNull);
    });

    test('旧版写成 0/1 的布尔值仍读得出来', () async {
      await file.writeAsString('background_task_reports: 0\n');
      expect(await store.getBool('background_task_reports'), false);
      await file.writeAsString('background_task_reports: 1\n');
      expect(await store.getBool('background_task_reports'), true);
    });

    test('get 拿到的是原始类型，不被转换', () async {
      // GUI 的旧整数模型 ID 迁移靠 is int 认出待换的旧值
      await store.set('chat_model_id', 3);
      expect(await store.get('chat_model_id'), 3);
      expect(await store.get('chat_model_id'), isA<int>());
    });

    test('写 null 等于删除该键', () async {
      await store.setString('theme_mode', 'dark');
      await store.set('theme_mode', null);
      expect(await store.getString('theme_mode'), isNull);
      expect(await file.readAsString(), isNot(contains('theme_mode')));
    });

    test('remove 后键消失；removing 不存在的键不改变文件', () async {
      await store.setString('theme_mode', 'dark');
      final before = await file.readAsString();
      await store.remove('chat_model_id');
      expect(await file.readAsString(), before);

      await store.remove('theme_mode');
      expect(await store.getString('theme_mode'), isNull);
    });

    test('clear 清空全部设置但保留文件', () async {
      await store.setString('model', 'm');
      await store.setInt('max_retries', 3);
      await store.clear();
      expect(await store.getString('model'), isNull);
      expect(await store.getInt('max_retries'), isNull);
      expect(await file.exists(), isTrue);
    });
  });

  group('两个前端共用一个文件', () {
    test('写一端的键不会抹掉另一端的键', () async {
      // GUI 写自己的偏好
      await store.setString('theme_mode', 'dark');
      await store.setDouble('window_width', 1200);
      // TUI 切换默认模型
      await store.saveModelId('deepseek-v4-flash');

      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getDouble('window_width'), 1200);
      expect(await store.loadModelId(), 'deepseek-v4-flash');
    });

    test('core 的具名访问器与通用接口读写同一批键', () async {
      await store.saveBraveApiKey('sk-abc');
      expect(await store.getString(UserSettingsStore.braveApiKeyKey), 'sk-abc');
      expect(await store.loadBraveApiKey(), 'sk-abc');

      await store.setString(UserSettingsStore.modelKey, 'm');
      expect(await store.loadModelId(), 'm');
    });

    test('两个实例交替写，后写的不会丢先前写的', () async {
      final gui = UserSettingsStore(file: file);
      final tui = UserSettingsStore(file: file);

      await gui.setString('theme_mode', 'dark');
      await tui.saveModelId('m');
      await gui.setInt('max_retries', 5);

      expect(await tui.getString('theme_mode'), 'dark');
      expect(await gui.loadModelId(), 'm');
      expect(await tui.getInt('max_retries'), 5);
    });

    test('并发写不同键全部保留', () async {
      final a = UserSettingsStore(file: file);
      final b = UserSettingsStore(file: file);
      await Future.wait([
        for (var i = 0; i < 10; i++) (i.isEven ? a : b).setInt('key_$i', i),
      ]);

      for (var i = 0; i < 10; i++) {
        expect(await a.getInt('key_$i'), i, reason: 'key_$i 被另一实例的整写覆盖');
      }
    });
  });

  group('文件容错', () {
    test('损坏的文件读时按空配置处理', () async {
      await file.writeAsString('model: "sk-unterminated\n');
      expect(await store.loadModelId(), isNull);
    });

    test('损坏的文件在写入前先备份', () async {
      const original = 'model: "sk-unterminated\n';
      await file.writeAsString(original);

      await store.saveModelId('deepseek-chat');

      final backups = backupsOf(file);
      expect(backups, hasLength(1));
      expect(backups.single.readAsStringSync(), original);
    });

    test('只有注释的空文件是正常空配置，不产生备份', () async {
      await file.writeAsString('# 只有注释\n');
      await store.saveModelId('deepseek-chat');
      expect(backupsOf(file), isEmpty);
      expect(await store.loadModelId(), 'deepseek-chat');
    });

    test('旧 GUI 遗留的脏段被丢弃且不再写回', () async {
      await file.writeAsString(
        'model: "m"\n'
        'currentModel: 3\n'
        'models: [1, 2]\n'
        'providers:\n  - id: "p"\n',
      );

      await store.saveModelId('m2');

      final content = await file.readAsString();
      expect(content, isNot(contains('currentModel')));
      expect(content, isNot(contains('models')));
      expect(content, isNot(contains('providers')));
    });

    test('嵌套结构被丢弃，但同文件里的标量不受影响', () async {
      await file.writeAsString('theme_mode: "dark"\nweird:\n  nested: 1\n');

      await store.setInt('max_retries', 3);

      final content = await file.readAsString();
      expect(content, isNot(contains('nested')));
      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getInt('max_retries'), 3);
    });

    test('写出的文件带可编辑的文件头注释', () async {
      await store.saveModelId('m');
      expect(await file.readAsString(), startsWith('# Athena 用户配置'));
    });

    test('写入是原子的：留下的是完整文件且没有临时文件残留', () async {
      await store.setString('theme_mode', 'dark');
      await store.setInt('max_retries', 3);

      expect(await store.getString('theme_mode'), 'dark');
      final leftovers = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('与文件锁共存', () {
    test('锁文件不参与数据读写', () async {
      await store.setString('theme_mode', 'dark');
      expect(await lockFileFor(file).exists(), isTrue);
      expect(await store.getString('theme_mode'), 'dark');
    });
  });
}
