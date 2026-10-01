import 'dart:io';

import 'package:athena_tui/di/tui_di.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late TuiDi di;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('athena_tui_di_');
    final skill = File(
      p.join(root.path, '.athena', 'skills', 'local', 'SKILL.md'),
    );
    await skill.parent.create(recursive: true);
    await skill.writeAsString('''
---
name: local
description: A skill from the injected home.
---
Only use this temporary home.
''');
    di = TuiDi(
      homeDir: root.path,
      dataDirectory: p.join(root.path, 'data'),
      workspace: root.path,
    );
  });

  tearDown(() async {
    di.chatController.dispose();
    await root.delete(recursive: true);
  });

  test('技能加载与重载使用显式 homeDir，而不是数据目录或环境 HOME', () {
    expect(di.skillRegistry.get('local')?.body, contains('temporary home'));
    expect(
      di.skillRegistry.skillsDirectory,
      p.join(root.path, '.athena', 'skills'),
    );
    di.skillRegistry.reload();
    expect(di.skillRegistry.get('local'), isNotNull);
  });

  test('经验保存与读取使用同一个显式 homeDir', () async {
    final experience = await di.experienceRepo.save(
      lesson: 'Use the injected home.',
      scope: 'shared',
      sentinelId: 'test',
    );
    final file = File(
      p.join(
        root.path,
        '.athena',
        'experiences',
        'shared',
        '${experience.id}.json',
      ),
    );
    expect(await file.exists(), isTrue);
    expect((await di.experienceRepo.listShared()).map((entry) => entry.id), [
      experience.id,
    ]);
  });
}
