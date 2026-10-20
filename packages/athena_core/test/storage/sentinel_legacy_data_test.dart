import 'dart:io';

import 'package:athena_core/agent/tool/sentinel_get_tool.dart';
import 'package:athena_core/agent/tool/sentinel_list_tool.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late FileStorage storage;
  final legacy = <String, dynamic>{
    'id': '7',
    'name': 'Reviewer',
    'avatar': 'legacy-avatar',
    'description': 'Review code',
    'prompt': 'Find correctness issues.',
    'tags': 'code,review',
    'is_preset': 0,
  };
  final currentFields = Map<String, dynamic>.of(legacy)..remove('avatar');

  /// 角色文件里的字段形态(camelCase,无 avatar)。
  const registeredFileFields = {
    'id': '7',
    'name': 'Reviewer',
    'description': 'Review code',
    'prompt': 'Find correctness issues.',
    'tags': 'code,review',
    'isPreset': false,
  };

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_sentinel_legacy_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.root.create(recursive: true);
    // 新布局:一个角色一个文件。这里直接手写文件内容,连"旧版遗留的 avatar
    // 字段"一起带上——读取侧要忽略它,编辑后不再写出。
    final file = File(p.join(storage.sentinelsDir.path, '7.yaml'));
    await file.parent.create(recursive: true);
    await file.writeAsString('''
id: "7"
name: "Reviewer"
avatar: "legacy-avatar"
description: "Review code"
prompt: "Find correctness issues."
tags: "code,review"
isPreset: false
''');
  });

  tearDown(() => temp.delete(recursive: true));

  test('旧角色文件保留全部有效字段，编辑后不再写出头像', () async {
    final repository = storage.sentinelRepository;
    final sentinel = (await repository.getAllSentinels()).single;
    expect(sentinel.toJson(), currentFields);

    await repository.updateSentinel(sentinel.copyWith(description: 'Updated'));
    final saved =
        loadYaml(
              await File(
                p.join(storage.sentinelsDir.path, '7.yaml'),
              ).readAsString(),
            )
            as Map;
    // 文件用 camelCase(与 provider 一致),toJson 用下划线;这里比对文件侧
    expect(saved, {...registeredFileFields, 'description': 'Updated'});

    final listing = await SentinelListTool(repository: repository).execute({});
    final details = await SentinelGetTool(
      repository: repository,
    ).execute({'sentinel_name': 'Reviewer'});
    expect(listing, contains('Updated'));
    expect(details, contains('Find correctness issues.'));
    expect('$listing\n$details', isNot(contains('Avatar')));
    expect('$listing\n$details', isNot(contains('legacy-avatar')));
  });
}
