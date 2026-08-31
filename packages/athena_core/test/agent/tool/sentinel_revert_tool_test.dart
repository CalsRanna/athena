import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/tool/sentinel_revert_tool.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

import 'in_memory_sentinel_repository.dart';

void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sentinel_revert_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SentinelHistoryStore newStore() => SentinelHistoryStore(homeDir: rootHome);

  SentinelRevertTool newTool(InMemorySentinelRepository repo) =>
      SentinelRevertTool(repository: repo, historyStore: newStore());

  test('无快照时拒绝回滚', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena', prompt: 'v1'));
    final result = await newTool(repo).execute({'sentinel_name': 'Athena'});
    expect(result, contains('No history snapshots found'));
  });

  test('snapshot_id 不存在报错', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena', prompt: 'v2'));
    final store = newStore();
    await store.save('Athena',
        SentinelEntity(id: 1, name: 'Athena', prompt: 'v1'), reason: 'r1');

    final result = await SentinelRevertTool(repository: repo, historyStore: store)
        .execute({'sentinel_name': 'Athena', 'snapshot_id': 'nope'});
    expect(result, contains('not found or corrupt'));
  });

  test('回滚恢复快照旧态，pre-revert 快照落库（回滚可回滚）', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena', prompt: 'v3'));
    final store = newStore();
    await store.save('Athena',
        SentinelEntity(id: 1, name: 'Athena', prompt: 'v1'), reason: 'evolve 1');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.save('Athena',
        SentinelEntity(id: 1, name: 'Athena', prompt: 'v2'), reason: 'evolve 2');

    final result = await SentinelRevertTool(repository: repo, historyStore: store)
        .execute({'sentinel_name': 'Athena', 'reason': 'worse after evolve'});
    expect(result, contains('reverted successfully'));

    // 默认回滚到最近快照（v2）
    expect(repo.sentinels.single.prompt, 'v2');
    final revertMeta = (await store.list('Athena')).first;
    expect(revertMeta.reason, contains('pre-revert state'));
    // 回滚本身也留了快照（1 原快照 + 1 pre-revert）
    expect(await store.list('Athena'), hasLength(3));
  });

  test('回滚撤销改名（跟随快照中的名字）', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(id: 1, name: 'Athena-v2', prompt: 'p2'));
    final store = newStore();
    await store.save('Athena-v2',
        SentinelEntity(id: 1, name: 'Athena', prompt: 'p1'), reason: 'rename');

    final result = await SentinelRevertTool(repository: repo, historyStore: store)
        .execute({'sentinel_name': 'Athena-v2'});
    expect(result, contains('reverted successfully'));
    expect(repo.sentinels.single.name, 'Athena');
  });

  test('快照名被其他 sentinel 占用时拒绝', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.addAll([
        SentinelEntity(id: 1, name: 'B-v2', prompt: 'p2'),
        SentinelEntity(id: 2, name: 'Athena', prompt: 'taken'),
      ]);
    final store = newStore();
    await store.save('B-v2',
        SentinelEntity(id: 1, name: 'Athena', prompt: 'p1'), reason: 'rename');

    final result = await SentinelRevertTool(repository: repo, historyStore: store)
        .execute({'sentinel_name': 'B-v2'});
    expect(result, contains('another sentinel named'));
    expect(repo.updates, isEmpty, reason: '冲突时不得落库');
  });

  test('不存在的 sentinel 报错', () async {
    final result =
        await newTool(InMemorySentinelRepository()).execute(
      {'sentinel_name': 'NoSuch'},
    );
    expect(result, contains('not found'));
  });
}
