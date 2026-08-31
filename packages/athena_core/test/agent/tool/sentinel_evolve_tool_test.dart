import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

import 'in_memory_sentinel_repository.dart';

/// 锁定 sentinel_evolve：变更前自动写入快照、变更报告含真实 diff。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sentinel_evolve_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SentinelHistoryStore newStore() => SentinelHistoryStore(homeDir: rootHome);

  int changed = 0;

  SentinelEvolveTool newTool(InMemorySentinelRepository repo) =>
      SentinelEvolveTool(
        repository: repo,
        historyStore: newStore(),
        onChanged: () => changed += 1,
      );

  setUp(() => changed = 0);

  test('更新前写入快照（旧态 + 变更原因），成功后回调触发', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena', prompt: 'v1'));
    final tool = newTool(repo);

    final result = await tool.execute({
      'sentinel_name': 'Athena',
      'improvements': 'Add a tone guideline',
      'new_prompt': 'v2 with tone guideline',
    });
    expect(result, contains('evolved successfully'));

    final metas = await newStore().list('Athena');
    expect(metas, hasLength(1));
    expect(metas.single.reason, 'Add a tone guideline');
    final snapshot = await newStore().load('Athena', metas.single.id);
    expect(snapshot!.prompt, 'v1', reason: '快照必须保存变更前的旧态');
    expect(changed, 1);
  });

  test('变更报告包含真实 diff 行（- 删除 / + 新增）与统计', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(
        id: 1,
        name: 'Athena',
        prompt: 'line one\nold behavior\nline three',
      ));
    final result = await newTool(repo).execute({
      'sentinel_name': 'Athena',
      'improvements': 'Fix behavior definition',
      'new_prompt': 'line one\nnew behavior\nline three',
    });

    expect(result, contains('## Evolution Report'));
    expect(result, contains('**Improvements:**'));
    expect(result, contains('Fix behavior definition'));
    // 行级 diff：变更行标注
    expect(result, contains('- old behavior'));
    expect(result, contains('+ new behavior'));
    // 未变行作上下文（带缩进）
    expect(result, contains('  line one'));
    // 统计信息
    expect(result, contains('1 removed, 1 added'));
  });

  test('内置 Athena 不可改名', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena', prompt: 'v1'));
    final result = await newTool(repo).execute({
      'sentinel_name': 'Athena',
      'improvements': 'x',
      'new_name': 'NewAthena',
      'new_prompt': 'v2',
    });
    expect(result, contains('cannot be renamed'));
  });
}
