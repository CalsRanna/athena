import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `setting.yaml` 的 `providers:` 段摊成 `providers/{id}.yaml` 的一次性升级。
void main() {
  late Directory temp;
  late FileStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_provider_files_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
  });
  tearDown(() => temp.delete(recursive: true));

  File providerFile(String id) =>
      File(p.join(storage.providersDir.path, '$id.yaml'));

  /// 把目录标成「整数 id 迁移已完成」,于是 [storage.load] 只跑本次的
  /// provider 文件迁移、原样读到用户手写的 YAML。
  ///
  /// 真实升级路径就是这样:老用户升级到带本迁移的版本时,`storage_version.json`
  /// 已经存在(整数 id 迁移是更早的一次发布做的),ID 迁移直接跳过,不会把
  /// setting.yaml 重写成 JSON。不写这一步的话,拿到的 setting.yaml 已被 ID
  /// 迁移转成 JSON——测的就不是用户真实的那份文件了。
  Future<void> skipIdMigration() async {
    await storage.root.create(recursive: true);
    await File(
      p.join(storage.root.path, 'storage_version.json'),
    ).writeAsString('{"version": 2, "legacy_model_ids": {}}');
  }

  test('段内每个 provider 一个文件，字段与 API key 原样保留', () async {
    await skipIdMigration();
    await storage.settingFile.writeAsString('''
model: "deepseek-v4-flash"
providers:
  - id: "01a0e62b-92e6-7264-b0f9-35ea7f5ccd9a"
    name: "Deep Seek"
    baseUrl: "https://api.deepseek.com/v1"
    apiKey: "sk-c819"
    apiFormat: "chat_completions"
    apiFormatAuto: true
    enabled: true
    isPreset: true
    createdAt: "2026-08-05T12:16:01.717"
  - id: "01a0e62b-92e7-7496-bf71-48a5057364b9"
    name: "Open Router"
    baseUrl: "https://openrouter.ai/api/v1"
    apiKey: "sk-or-v1"
    apiFormat: "responses"
    apiFormatAuto: false
    enabled: false
    isPreset: true
    createdAt: "2026-08-05T12:16:01.717"
''');

    await storage.load();

    final providers = await storage.providerRepository.getAllProviders();
    expect(providers.map((p) => p.name), ['Deep Seek', 'Open Router']);
    expect(
      providers.first.id,
      '01a0e62b-92e6-7264-b0f9-35ea7f5ccd9a',
      reason: 'id 原样保留，作为文件名',
    );
    expect(providers.first.apiKey, 'sk-c819');
    expect(providers.first.enabled, isTrue);
    expect(providers.first.apiFormat, ApiFormat.chatCompletions);
    expect(providers.first.apiFormatAuto, isTrue);
    expect(providers.last.apiFormat, ApiFormat.responses);
    expect(providers.last.apiFormatAuto, isFalse);
    expect(providers.first.createdAt, DateTime(2026, 8, 5, 12, 16, 1, 717));
    // 数据文件在，段已从 setting.yaml 移除，默认模型不受影响
    expect(
      await providerFile('01a0e62b-92e6-7264-b0f9-35ea7f5ccd9a').exists(),
      isTrue,
    );
    expect(
      await storage.settingFile.readAsString(),
      isNot(contains('providers:')),
    );
    expect(await storage.userSettings.loadModelId(), 'deepseek-v4-flash');
  });

  test('原 setting.yaml 留一份完整备份', () async {
    await skipIdMigration();
    const original =
        'model: m\nproviders:\n'
        '  - id: "p1"\n    name: "P"\n    apiKey: "sk-secret"\n';
    await storage.settingFile.writeAsString(original);

    await storage.load();

    final backups = storage.settingFile.parent
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              p.basename(f.path).startsWith('setting.yaml.pre-provider-files-'),
        )
        .toList();
    expect(backups, hasLength(1));
    expect(backups.single.readAsStringSync(), original);
  });

  test('重复启动不重复迁移，用户删光 provider 后也不会从旧段复活', () async {
    await skipIdMigration();
    await storage.settingFile.writeAsString(
      'providers:\n  - id: "p1"\n    name: "P"\n    apiKey: "k"\n',
    );

    await storage.load();
    expect(await storage.providerRepository.getProvidersCount(), 1);

    await storage.providerRepository.deleteAllProviders();
    expect(await storage.providerRepository.getProvidersCount(), 0);

    // 第二次启动：标记已落盘，目录为空是用户的选择，不再尝试迁移
    await storage.load();
    expect(await storage.providerRepository.getProvidersCount(), 0);
    expect(
      await storage.settingFile.readAsString(),
      isNot(contains('providers:')),
    );
  });

  test('id 不合法时整批中止，原 setting.yaml 与备份完整保留', () async {
    await skipIdMigration();
    const original =
        'providers:\n'
        '  - id: "ok"\n    name: "Fine"\n'
        '  - id: "../escape"\n    name: "Bad"\n';
    await storage.settingFile.writeAsString(original);

    await expectLater(storage.load(), throwsFormatException);

    expect(await storage.settingFile.readAsString(), original);
    expect(
      await providerFile('ok').exists(),
      isFalse,
      reason: '先整体校验再落盘，不能写一半',
    );
    expect(await storage.providersDir.exists(), isFalse);
  });

  test('没有 providers 段（新装或已迁移）直接落标记并跳过', () async {
    await storage.settingFile.parent.create(recursive: true);
    await storage.settingFile.writeAsString('model: "m"\n');

    await storage.load();

    expect(await storage.providerRepository.getProvidersCount(), 0);
    expect(
      await File(p.join(storage.providersDir.path, '.version')).exists(),
      isTrue,
    );
  });

  test('迁移不做字段解释，手工写入的额外键一起带过去', () async {
    await skipIdMigration();
    await storage.settingFile.writeAsString(
      'providers:\n'
      '  - id: "p1"\n'
      '    name: "P"\n'
      '    apiKey: "k"\n'
      '    myNote: "keep me"\n',
    );

    await storage.load();

    expect(
      await providerFile('p1').readAsString(),
      contains('myNote: "keep me"'),
    );
  });
}
