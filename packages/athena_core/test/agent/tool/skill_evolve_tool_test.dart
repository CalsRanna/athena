import 'dart:io';

import 'package:athena_core/agent/evolution/skill_history_store.dart';
import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_revert_tool.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late SkillRegistry registry;
  late SkillHistoryStore history;
  late SkillEvolveTool tool;
  late SkillRevertTool revert;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_skill_evolve_');
    registry = SkillRegistry()..loadAll(homeDir: root.path);
    history = SkillHistoryStore(homeDir: root.path);
    tool = SkillEvolveTool(
      skillRegistry: registry,
      historyStore: history,
      homeDir: root.path,
    );
    revert = SkillRevertTool(skillRegistry: registry, historyStore: history);
  });
  tearDown(() => root.deleteSync(recursive: true));

  File skillFile(String name) =>
      File('${root.path}/.athena/skills/$name/SKILL.md');

  Future<String> create(String name, String body) => tool.execute({
    'name': name,
    'action': 'create',
    'description': 'demo skill',
    'body': body,
  });

  test(
    'an unknown action cannot create a file even when called directly',
    () async {
      final result = await tool.executeResult({
        'name': 'demo',
        'action': 'archive',
        'description': 'demo',
        'body': 'demo',
      });
      expect(result.status, ToolResultStatus.executionError);
      expect(skillFile('demo').existsSync(), isFalse);
    },
  );

  test(
    'built-in skills cannot be written to a relative builtin directory',
    () async {
      registry.registerBuiltin(
        const Skill(
          name: 'builtin',
          description: 'demo',
          body: 'original',
          sourcePath: '(builtin)',
        ),
      );
      final result = await tool.executeResult({
        'name': 'builtin',
        'action': 'update',
        'body': 'changed',
      });
      expect(result.status, ToolResultStatus.executionError);
      expect(registry.get('builtin')!.body, 'original');
    },
  );

  test('update snapshots the previous version and reports its id', () async {
    await create('demo', 'v1 body');

    final result = await tool.execute({
      'name': 'demo',
      'action': 'update',
      'body': 'v2 body',
    });

    expect(result, contains('Successfully updated skill "demo"'));
    expect(result, contains('snapshot'), reason: '模型需要拿到 id 才能回滚');
    expect(registry.get('demo')!.body, 'v2 body');
    final metas = await history.list('demo');
    expect(metas, hasLength(1));
    expect(result, contains(metas.single.id));
  });

  test('create does not snapshot: there is nothing to overwrite', () async {
    await create('fresh', 'first body');

    expect(await history.list('fresh'), isEmpty);
  });

  test('revert restores the previous body and is itself revertible', () async {
    await create('demo', 'v1 body');
    await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v2'});

    final restored = await revert.execute({'name': 'demo'});
    expect(restored, isNot(startsWith('Error:')));
    expect(registry.get('demo')!.body, 'v1 body');

    // 回滚前也存了一份快照（v2），所以再回滚一次应回到 v2。
    final second = await revert.execute({'name': 'demo'});
    expect(second, isNot(startsWith('Error:')));
    expect(registry.get('demo')!.body, 'v2');
  });

  test('list_only enumerates snapshots without touching the skill', () async {
    await create('demo', 'v1');
    await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v2'});
    final before = registry.get('demo')!.body;

    final listed = await revert.execute({'name': 'demo', 'list_only': true});

    expect(listed, contains('Snapshots for "demo"'));
    expect(registry.get('demo')!.body, before);
  });

  test('revert to a specific older snapshot', () async {
    await create('demo', 'v1');
    await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v2'});
    final firstSnapshot = (await history.list('demo')).single.id;
    await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v3'});

    final result = await revert.execute({
      'name': 'demo',
      'snapshot_id': firstSnapshot,
    });

    expect(result, isNot(startsWith('Error:')));
    expect(registry.get('demo')!.body, 'v1');
  });

  test('revert without history fails with a hint', () async {
    await create('demo', 'v1');

    final result = await revert.execute({'name': 'demo'});

    expect(result, startsWith('Error: No history snapshots'));
  });

  test('body over the limit is rejected before writing', () async {
    final huge = 'x' * (SkillEvolveTool.maxBodyChars + 1);

    final result = await tool.execute({
      'name': 'too-big',
      'action': 'create',
      'description': 'demo',
      'body': huge,
    });

    expect(result, startsWith('Error:'));
    expect(result, contains('${SkillEvolveTool.maxBodyChars}'));
    expect(skillFile('too-big').existsSync(), isFalse);
  });

  test('body at the limit is accepted', () async {
    final exact = 'x' * SkillEvolveTool.maxBodyChars;

    final result = await tool.execute({
      'name': 'exact',
      'action': 'create',
      'description': 'demo',
      'body': exact,
    });

    expect(result, contains('Successfully created'));
    expect(registry.get('exact')!.body.length, SkillEvolveTool.maxBodyChars);
  });

  test('delete removes the skill and its history', () async {
    await create('demo', 'v1');
    await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v2'});
    expect(await history.list('demo'), isNotEmpty);

    final result = await tool.execute({'name': 'demo', 'action': 'delete'});

    expect(result, isNot(startsWith('Error:')));
    expect(registry.get('demo'), isNull);
    expect(skillFile('demo').existsSync(), isFalse);
    expect(
      Directory('${root.path}/.athena/skills/demo/history').existsSync(),
      isFalse,
    );
  });

  test('built-in skills cannot be deleted or reverted', () async {
    registry.registerBuiltin(
      const Skill(
        name: 'builtin',
        description: 'demo',
        body: 'original',
        sourcePath: '(builtin)',
      ),
    );

    expect(
      await tool.execute({'name': 'builtin', 'action': 'delete'}),
      startsWith('Error: Built-in skills cannot be deleted'),
    );
    expect(
      await revert.execute({'name': 'builtin'}),
      startsWith('Error: Built-in skills cannot be reverted'),
    );
  });

  test('history is capped per skill, keeping the newest', () async {
    await create('demo', 'v0');
    for (var i = 1; i <= SkillHistoryStore.maxSnapshotsPerSkill + 5; i++) {
      await tool.execute({'name': 'demo', 'action': 'update', 'body': 'v$i'});
    }

    final metas = await history.list('demo');
    expect(metas, hasLength(SkillHistoryStore.maxSnapshotsPerSkill));
    // 最新的快照应当对应倒数第二次写入，即 v55 之前的 v55? —— 只需确认
    // 最旧的那些已被删掉：第一条快照的 reason 全部是 pre-update state，
    // 因此改为验证还能回滚到最后保存的那一版。
    final latest = await history.load('demo', metas.first.id);
    expect(latest, contains('v${SkillHistoryStore.maxSnapshotsPerSkill + 4}'));
  });
}
