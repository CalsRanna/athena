import 'dart:io';

import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
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

    test('project skill update stays trusted and loaded (native separators)',
        () async {
      final projectRoot = tmp.path;
      final skillDir =
          Directory(p.join(projectRoot, '.athena', 'skills', 'demo'))
            ..createSync(recursive: true);
      writeSkill(skillDir, 'v1');

      final trustStore = SkillTrustStore(
        file: File(p.join(tmp.path, 'trusted.json')),
      );
      await trustStore.trust(projectRoot);

      final registry = SkillRegistry(trustStore: trustStore);
      registry.loadAll(
        homeDir: p.join(tmp.path, 'home'),
        projectDir: projectRoot,
      );
      expect(registry.get('demo'), isNotNull);

      // skill_evolve 更新 Skill 后触发 reloadSkill；
      // Windows 上 skillDir.path 为反斜杠分隔（回归：此前 _findProjectRoot
      // 硬编码 '/' 导致项目根识别失败，已信任的 Skill 被放回 pending）。
      writeSkill(skillDir, 'v2');
      registry.reloadSkill('demo', skillDir.path);

      expect(registry.get('demo'), isNotNull,
          reason: '已信任的项目 Skill 更新后应保持可用，不得回到 pending');
      expect(registry.get('demo')!.description, 'v2');
      expect(registry.pendingProjectSkills, isEmpty);
      expect(registry.pendingProjectDir, isNull);
    });

    test('user skill update stays in user scope', () async {
      final home = p.join(tmp.path, 'home');
      final skillDir =
          Directory(p.join(home, '.athena', 'skills', 'demo'))
            ..createSync(recursive: true);
      writeSkill(skillDir, 'v1');

      final registry = SkillRegistry();
      registry.loadAll(
        homeDir: home,
        projectDir: p.join(tmp.path, 'project'),
      );
      expect(registry.get('demo'), isNotNull);

      writeSkill(skillDir, 'v2');
      registry.reloadSkill('demo', skillDir.path);

      expect(registry.get('demo'), isNotNull);
      expect(registry.get('demo')!.description, 'v2');
      expect(registry.pendingProjectSkills, isEmpty);
    });
  });
}
