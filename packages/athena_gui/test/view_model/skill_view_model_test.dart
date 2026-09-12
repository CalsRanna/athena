import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late SkillRegistry registry;
  late SkillViewModel viewModel;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skill_vm_test');
    registry = SkillRegistry()..loadAll(homeDir: tmp.path);
    viewModel = SkillViewModel(skillRegistry: registry);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('createSkill 写入文件并刷新列表', () async {
    final ok = await viewModel.createSkill(
      name: 'demo',
      description: 'A demo',
      allowedTools: 'file_read',
      body: '## Steps',
    );

    expect(ok, isTrue);
    expect(
      File('${tmp.path}/.athena/skills/demo/SKILL.md').existsSync(),
      isTrue,
    );
    expect(viewModel.userSkills.value.map((s) => s.name), ['demo']);
    expect(viewModel.userSkills.value.single.allowedTools, 'file_read');
  });

  test('createSkill 拒绝非法名与重复名', () async {
    expect(
      await viewModel.createSkill(name: 'bad/name', description: 'd', body: 'b'),
      isFalse,
    );
    expect(viewModel.error.value, isNotNull);

    await viewModel.createSkill(name: 'demo', description: 'd', body: 'b');
    expect(
      await viewModel.createSkill(name: 'demo', description: 'd', body: 'b'),
      isFalse,
    );
  });

  test('updateSkill 覆盖内容；内置 Skill 拒绝修改与删除', () async {
    await viewModel.createSkill(name: 'demo', description: 'v1', body: 'b1');
    final skill = viewModel.userSkills.value.single;

    expect(
      await viewModel.updateSkill(skill, description: 'v2', body: 'b2'),
      isTrue,
    );
    expect(registry.get('demo')!.description, 'v2');

    registry.registerBuiltin(
      const Skill(
        name: 'builtin-x',
        description: 'd',
        body: 'b',
        sourcePath: '(builtin)',
      ),
    );
    final builtin = registry.get('builtin-x')!;
    expect(
      await viewModel.updateSkill(builtin, description: 'x', body: 'y'),
      isFalse,
    );
    expect(await viewModel.deleteSkill(builtin), isFalse);
    expect(registry.get('builtin-x'), isNotNull);
  });

  test('deleteSkill 删除用户级目录并刷新列表', () async {
    await viewModel.createSkill(name: 'demo', description: 'd', body: 'b');
    final skill = viewModel.userSkills.value.single;

    expect(await viewModel.deleteSkill(skill), isTrue);
    expect(
      Directory('${tmp.path}/.athena/skills/demo').existsSync(),
      isFalse,
    );
    expect(viewModel.userSkills.value, isEmpty);
  });

  test('userSkills 过滤内置 Skill', () async {
    registry.registerBuiltin(
      const Skill(
        name: 'builtin-x',
        description: 'd',
        body: 'b',
        sourcePath: '(builtin)',
      ),
    );
    await viewModel.load();

    expect(viewModel.skills.value, hasLength(1));
    expect(viewModel.userSkills.value, isEmpty);
  });
}
