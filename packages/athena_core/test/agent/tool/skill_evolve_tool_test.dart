import 'dart:io';

import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:test/test.dart';

/// 锁定 skill_evolve 的行为：Skill 统一写入用户级目录
/// （`homeDir/.athena/skills/`），homeDir 为空时使用系统 $HOME（桌面端）。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skill_evolve_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SkillRegistry newRegistry({required String? homeDir}) {
    final registry = SkillRegistry();
    registry.loadAll(homeDir: homeDir);
    return registry;
  }

  Future<String> runCreate({
    required SkillRegistry registry,
    required String homeDir,
    String name = 'test-skill',
  }) {
    return SkillEvolveTool(
      skillRegistry: registry,
      homeDir: homeDir,
    ).execute({
      'name': name,
      'action': 'create',
      'description': 'A test skill',
      'body': '## Usage\n\nDo the thing.',
    });
  }

  test('创建时写入 homeDir 下的用户级目录并立即可用', () async {
    final registry = newRegistry(homeDir: rootHome);
    final result = await runCreate(registry: registry, homeDir: rootHome);

    expect(result, contains('$rootHome/.athena/skills/test-skill/SKILL.md'));
    final skillFile = File('$rootHome/.athena/skills/test-skill/SKILL.md');
    expect(skillFile.existsSync(), isTrue);
    // reloadSkill 归类为用户级技能，立即可用
    expect(registry.get('test-skill'), isNotNull);
  });

  test('update 复用已有技能目录', () async {
    final registry = newRegistry(homeDir: rootHome);
    await runCreate(registry: registry, homeDir: rootHome);

    final result = await SkillEvolveTool(
      skillRegistry: registry,
      homeDir: rootHome,
    ).execute({
      'name': 'test-skill',
      'action': 'update',
      'body': '## Usage\n\nUpdated instructions.',
    });

    expect(result, contains('Successfully'));
    final skillFile = File('$rootHome/.athena/skills/test-skill/SKILL.md');
    expect(skillFile.readAsStringSync(), contains('Updated instructions.'));
  });

  test('非法 Skill 名被拒绝', () async {
    final registry = newRegistry(homeDir: rootHome);
    final result = await SkillEvolveTool(
      skillRegistry: registry,
      homeDir: rootHome,
    ).execute({
      'name': 'bad/name',
      'action': 'create',
      'description': 'A test skill',
      'body': 'body',
    });

    expect(result, contains('Invalid skill name'));
    expect(File('$rootHome/.athena/skills/bad/name/SKILL.md').existsSync(),
        isFalse);
  });
}
