import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_update_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:path/path.dart' as p;
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

  test('默认通过 skill 工具加载内置创建技能，无需用户安装', () async {
    final result = await tool.executeResult({'name': 'skill-creator'});

    expect(result.status, ToolResultStatus.success);
    expect(result.text, contains(registry.get('skill-creator')!.body));
    expect(result.text, contains(p.absolute(registry.skillsDirectory)));
    expect(registry.currentContext?.name, 'skill-creator');
    expect(registry.currentContext?.isBuiltin, isTrue);
    expect(
      Directory('${registry.skillsDirectory}/skill-creator').existsSync(),
      isFalse,
    );
  });

  test('现有文件工具保存技能和资源后，无需手动刷新即可加载', () async {
    const content = '''
---
name: meeting-summary
description: "Summarize decisions: list owners and deadlines."
---
# Meeting summary
Read references/format.md and summarize the supplied notes.
''';
    final directory = p.join(registry.skillsDirectory, 'meeting-summary');
    final path = resolveRealPathSync(p.join(directory, 'SKILL.md'));
    final writer = FileWriteTool();
    final saved = await writer.executeResult({
      'path': path,
      'content': content,
    });
    expect(saved.status, ToolResultStatus.success);
    final resource = await writer.executeResult({
      'path': resolveRealPathSync(p.join(directory, 'references', 'format.md')),
      'content': 'List decisions and action items.',
    });
    expect(resource.status, ToolResultStatus.success);

    final loaded = await tool.executeResult({'name': 'meeting-summary'});
    expect(loaded.status, ToolResultStatus.success);
    expect(loaded.text, contains('# Meeting summary'));
    expect(registry.level1Prompt, contains('**meeting-summary**'));
    expect(
      await tool.execute({
        'name': 'meeting-summary',
        'resource': 'references/format.md',
      }),
      contains('List decisions and action items.'),
    );
    expect(
      await FileReadTool().execute({'path': path}),
      contains('# Meeting summary'),
    );

    final updated = await FileUpdateTool().executeResult({
      'path': path,
      'old_string': '# Meeting summary',
      'new_string': '# Updated summary',
    });
    expect(updated.status, ToolResultStatus.success);
    expect(
      await tool.execute({'name': 'meeting-summary'}),
      contains('# Updated summary'),
    );

    final restarted = SkillRegistry()..loadAll(homeDir: root.path);
    expect(
      restarted.get('meeting-summary')!.body,
      contains('# Updated summary'),
    );
  });

  test('磁盘上的技能已失效时不继续返回缓存正文', () async {
    File(
      p.join(registry.skillsDirectory, 'demo', 'SKILL.md'),
    ).writeAsStringSync('invalid skill');

    final result = await tool.executeResult({'name': 'demo'});

    expect(result.status, ToolResultStatus.executionError);
    expect(registry.all.any((skill) => skill.name == 'demo'), isFalse);
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
