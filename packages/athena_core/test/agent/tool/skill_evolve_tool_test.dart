import 'dart:io';

import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:test/test.dart';

/// 锁定 skill_evolve 的移动端行为：默认（且只能）写 user 级目录，
/// 根目录由 homeDir 指定（沙盒内 Application Support，而非 $HOME）。
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
    required bool mobile,
    String? homeDir,
    String? scope,
    String name = 'test-skill',
  }) {
    return SkillEvolveTool(
      skillRegistry: registry,
      homeDir: homeDir,
      mobile: mobile,
    ).execute({
      'name': name,
      'action': 'create',
      'description': 'A test skill',
      'body': '## Usage\n\nDo the thing.',
      if (scope != null) 'scope': scope,
    });
  }

  test('移动端未传 scope 时默认写 user 级(homeDir 根)', () async {
    final registry = newRegistry(homeDir: rootHome);
    final result =
        await runCreate(registry: registry, mobile: true, homeDir: rootHome);

    expect(result, contains('$rootHome/.athena/skills/test-skill/SKILL.md'));
    final skillFile = File('$rootHome/.athena/skills/test-skill/SKILL.md');
    expect(skillFile.existsSync(), isTrue);
    // reloadSkill 归类为用户级技能,立即可用
    expect(registry.get('test-skill'), isNotNull);
  });

  test('移动端显式 scope=project 也映射到 user 级', () async {
    final registry = newRegistry(homeDir: rootHome);
    final result = await runCreate(
      registry: registry,
      mobile: true,
      homeDir: rootHome,
      scope: 'project',
    );

    expect(result, contains('$rootHome/.athena/skills/test-skill/SKILL.md'));
    expect(File('$rootHome/.athena/skills/test-skill/SKILL.md').existsSync(),
        isTrue);
  });

  test('桌面端 scope=user 使用 homeDir 覆盖,不依赖系统 HOME', () async {
    final registry = newRegistry(homeDir: rootHome);
    final result = await runCreate(
      registry: registry,
      mobile: false,
      homeDir: rootHome,
      scope: 'user',
    );

    expect(result, contains('$rootHome/.athena/skills/test-skill/SKILL.md'));
  });

  test('移动端 update 复用已有技能目录', () async {
    final registry = newRegistry(homeDir: rootHome);
    await runCreate(registry: registry, mobile: true, homeDir: rootHome);

    final result = await SkillEvolveTool(
      skillRegistry: registry,
      homeDir: rootHome,
      mobile: true,
    ).execute({
      'name': 'test-skill',
      'action': 'update',
      'body': '## Usage\n\nUpdated instructions.',
    });

    expect(result, contains('Successfully'));
    final skillFile = File('$rootHome/.athena/skills/test-skill/SKILL.md');
    expect(skillFile.readAsStringSync(), contains('Updated instructions.'));
  });
}
