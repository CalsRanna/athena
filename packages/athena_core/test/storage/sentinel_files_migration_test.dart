import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// `sentinels.json` 数组 → 每角色一个文件。
void main() {
  late Directory temp;
  late FileStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_sentinel_files_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.root.create(recursive: true);
    await File(
      p.join(storage.root.path, '.storage_version'),
    ).writeAsString('{"version": 2, "legacy_model_ids": {}}');
  });
  tearDown(() => temp.delete(recursive: true));

  Future<void> writeSentinels(List<Map<String, dynamic>> sentinels) =>
      storage.sentinelsFile.writeAsString(jsonEncode(sentinels));

  Map<String, dynamic> sentinel(String id, String name) => {
    'id': id,
    'name': name,
    'description': 'd',
    'prompt': 'p',
    'tags': 'a,b',
    'is_preset': 1,
  };

  File sentinelFile(String id) =>
      File(p.join(storage.sentinelsDir.path, '$id.yaml'));

  test('每个角色一个文件，字段原样保留，id 用作文件名', () async {
    await writeSentinels([
      sentinel('s1', 'Athena'),
      sentinel('s2', 'Reviewer'),
    ]);

    await storage.load();

    final all = await storage.sentinelRepository.getAllSentinels();
    expect(all.map((s) => s.name), ['Athena', 'Reviewer']);
    expect(all.map((s) => s.id).toSet(), {'s1', 's2'});
    expect(all.first.tags, 'a,b');
    expect(all.first.isPreset, isTrue);

    final raw = loadYaml(await sentinelFile('s1').readAsString()) as Map;
    expect(raw['name'], 'Athena');
    expect(raw['id'], 's1');

    expect(await storage.sentinelsFile.exists(), isFalse);
    expect(
      await File('${storage.sentinelsFile.path}.migrated').exists(),
      isTrue,
    );
  });

  test('与角色快照目录（by-id/ 与旧的名字目录）互不干扰', () async {
    // SentinelHistoryStore 在同一目录下用 by-id/{id}/history/*.json 与
    // {name}/history/*.json 存快照;角色文件是目录下的 .yaml 文件,
    // 列举时只取 .yaml,不会把目录当成角色、也不会被快照干扰。
    await writeSentinels([sentinel('s1', 'Reviewer')]);
    final legacyHistory = File(
      p.join(storage.sentinelsDir.path, 'Reviewer', 'history', 'old.json'),
    );
    await legacyHistory.parent.create(recursive: true);
    await legacyHistory.writeAsString('{}');

    await storage.load();

    expect(await storage.sentinelRepository.getAllSentinels(), hasLength(1));
    expect(
      await storage.sentinelRepository.getSentinelById('Reviewer'),
      isNull,
      reason: '目录名不是角色',
    );
  });

  test('id 不合法时整批中止，原文件与备份完整保留', () async {
    final data = [sentinel('ok', 'Fine'), sentinel('../escape', 'Bad')];
    await writeSentinels(data);

    await expectLater(storage.load(), throwsFormatException);

    expect(await storage.sentinelsFile.exists(), isTrue);
    expect(await sentinelFile('ok').exists(), isFalse, reason: '先校验再落盘');
    expect(await storage.sentinelsDir.exists(), isFalse);
  });

  test('重复启动幂等', () async {
    await writeSentinels([sentinel('s1', 'Athena')]);

    await storage.load();
    await storage.load();
    await FileStorage(root: storage.root).load();

    expect(await storage.sentinelRepository.getAllSentinels(), hasLength(1));
  });

  test('原文件损坏时中止并保留', () async {
    await storage.sentinelsFile.writeAsString('[{"id": "s1"');

    await expectLater(storage.load(), throwsFormatException);

    expect(await storage.sentinelsFile.exists(), isTrue);
  });

  test('没有 sentinels.json（新装）直接落标记，种子照常生效', () async {
    await storage.load();

    expect(await storage.sentinelRepository.getSentinelsCount(), 0);
    expect(
      await File(p.join(storage.sentinelsDir.path, '.version')).exists(),
      isTrue,
    );
  });
}
