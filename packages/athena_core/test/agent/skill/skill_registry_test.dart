import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
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

  group('SkillRegistry.deleteSkill / reload', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('athena_skill_delete_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    SkillRegistry loadedRegistry(String home, {String description = 'v1'}) {
      final skillDir = Directory(p.join(home, '.athena', 'skills', 'demo'))
        ..createSync(recursive: true);
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(
        '---\nname: demo\ndescription: $description\n---\nbody',
      );
      final registry = SkillRegistry();
      registry.loadAll(homeDir: home);
      return registry;
    }

    test('deleteSkill 删除用户级目录并从内存移除', () {
      final home = p.join(tmp.path, 'home');
      final registry = loadedRegistry(home);

      expect(registry.deleteSkill('demo'), isTrue);
      expect(registry.get('demo'), isNull);
      expect(
        Directory(p.join(home, '.athena', 'skills', 'demo')).existsSync(),
        isFalse,
      );
    });

    test('内置 Skill 或不存在时返回 false', () {
      final registry = SkillRegistry();
      registry.registerBuiltin(
        const Skill(
          name: 'builtin-demo',
          description: 'd',
          body: 'b',
          sourcePath: '(builtin)',
        ),
      );

      expect(registry.deleteSkill('builtin-demo'), isFalse);
      expect(registry.get('builtin-demo'), isNotNull);
      expect(registry.deleteSkill('missing'), isFalse);
    });

    test('reload 重新扫描磁盘并拾取变化', () {
      final home = p.join(tmp.path, 'home');
      final registry = loadedRegistry(home);
      expect(registry.get('demo')!.description, 'v1');

      File(p.join(home, '.athena', 'skills', 'demo', 'SKILL.md'))
          .writeAsStringSync(
        '---\nname: demo\ndescription: v2\n---\nbody',
      );
      final secondDir = Directory(p.join(home, '.athena', 'skills', 'extra'))
        ..createSync(recursive: true);
      File(p.join(secondDir.path, 'SKILL.md')).writeAsStringSync(
        '---\nname: extra\ndescription: e\n---\nbody',
      );

      registry.reload();
      expect(registry.get('demo')!.description, 'v2');
      expect(registry.get('extra'), isNotNull);
    });
  });
}
