import 'dart:io';

import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SkillRegistry.reloadSkill', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('athena_skill_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    void writeSkill(Directory skillDir, String description) {
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(
        '---\nname: demo\ndescription: $description\n---\nbody',
      );
    }

    test('user skill update is reloaded and takes effect', () async {
      final home = p.join(tmp.path, 'home');
      final skillDir =
          Directory(p.join(home, '.athena', 'skills', 'demo'))
            ..createSync(recursive: true);
      writeSkill(skillDir, 'v1');

      final registry = SkillRegistry();
      registry.loadAll(homeDir: home);
      expect(registry.get('demo'), isNotNull);

      // skill_evolve 更新 Skill 后触发 reloadSkill。
      writeSkill(skillDir, 'v2');
      registry.reloadSkill('demo', skillDir.path);

      expect(registry.get('demo'), isNotNull);
      expect(registry.get('demo')!.description, 'v2');
    });

    test('reloadSkill removes skill when file is deleted', () async {
      final home = p.join(tmp.path, 'home');
      final skillDir =
          Directory(p.join(home, '.athena', 'skills', 'demo'))
            ..createSync(recursive: true);
      writeSkill(skillDir, 'v1');

      final registry = SkillRegistry();
      registry.loadAll(homeDir: home);
      expect(registry.get('demo'), isNotNull);

      File(p.join(skillDir.path, 'SKILL.md')).deleteSync();
      registry.reloadSkill('demo', skillDir.path);

      expect(registry.get('demo'), isNull);
    });
  });
}
