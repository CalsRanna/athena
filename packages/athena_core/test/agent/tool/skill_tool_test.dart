import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:test/test.dart';

/// `skill` 工具的 resource 参数是模型可以直接指定的相对路径：边界与
/// 「哪些目录算资源」都必须守住，否则技能目录里的内部文件会被当作参考
/// 资料读回上下文。
void main() {
  late Directory root;
  late SkillRegistry registry;
  late SkillTool tool;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_skill_tool_');
    Directory('${root.path}/.athena/skills/demo').createSync(recursive: true);
    SkillLoader().saveSkill(
      name: 'demo',
      description: 'demo skill',
      body: 'follow the reference',
      targetDir: '${root.path}/.athena/skills/demo',
    );
    Directory(
      '${root.path}/.athena/skills/demo/references',
    ).createSync(recursive: true);
    File(
      '${root.path}/.athena/skills/demo/references/guide.md',
    ).writeAsStringSync('guide line');
    registry = SkillRegistry()..loadAll(homeDir: root.path);
    tool = SkillTool(registry);
  });

  tearDown(() => root.deleteSync(recursive: true));

  Map<String, dynamic> args(Map<String, dynamic> extra) => {
    'name': 'demo',
    'call_description': 'load a skill',
    ...extra,
  };

  test('加载技能返回正文，并标记为当前上下文', () async {
    final result = await tool.execute(args({}));

    expect(result, contains('follow the reference'));
    expect(registry.currentContext?.name, 'demo');
  });

  test('读取技能目录内的资源文件', () async {
    final result = await tool.execute(
      args({'resource': 'references/guide.md'}),
    );

    expect(result, contains('guide line'));
  });

  test('资源路径不能穿越到技能目录之外', () async {
    File('${root.path}/outside.txt').writeAsStringSync('secret');

    for (final resource in ['../outside.txt', '../../.athena/skills/x.md']) {
      final result = await tool.execute(args({'resource': resource}));
      expect(result, startsWith('Error:'), reason: resource);
      expect(result, isNot(contains('secret')));
    }
  });

  test('history 目录是内部快照，不作为资源提供', () async {
    Directory(
      '${root.path}/.athena/skills/demo/history',
    ).createSync(recursive: true);
    File(
      '${root.path}/.athena/skills/demo/history/old.json',
    ).writeAsStringSync('{"content":"obsolete instructions"}');

    final result = await tool.execute(args({'resource': 'history/old.json'}));

    expect(result, startsWith('Error:'));
    expect(result, isNot(contains('obsolete instructions')));
    expect(result, contains('previous versions'));
  });

  test('内置技能没有资源目录', () async {
    registry.registerBuiltin(
      const Skill(
        name: 'builtin',
        description: 'demo',
        body: 'body',
        sourcePath: '(builtin)',
      ),
    );

    expect(
      await tool.execute({
        'name': 'builtin',
        'resource': 'x.md',
        'call_description': 'read',
      }),
      startsWith('Error: Built-in skill'),
    );
  });

  test('offset/limit 只在读取资源时有效', () async {
    final result = await tool.execute(args({'offset': 1}));

    expect(result, startsWith('Error:'));
    expect(result, contains('require a resource'));
  });
}
