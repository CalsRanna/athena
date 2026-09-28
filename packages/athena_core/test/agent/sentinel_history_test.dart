import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/agent/tool/sentinel_revert_tool.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 演进可以改名：快照必须跟着角色（id）走，而不是跟着名字走。
void main() {
  late Directory temp;
  late FileStorage storage;
  late SentinelHistoryStore history;
  late SentinelEvolveTool evolve;
  late SentinelRevertTool revert;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_sentinel_history_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.load();
    history = SentinelHistoryStore(homeDir: temp.path);
    evolve = SentinelEvolveTool(
      repository: storage.sentinelRepository,
      historyStore: history,
    );
    revert = SentinelRevertTool(
      repository: storage.sentinelRepository,
      historyStore: history,
    );
  });

  tearDown(() => temp.delete(recursive: true));

  Future<int> createSentinel(String name, String prompt) => storage
      .sentinelRepository
      .createSentinel(SentinelEntity(name: name, prompt: prompt));

  test('改名后用新名字回滚：名字与提示词一起撤销', () async {
    final id = await createSentinel('Reviewer', 'v1');
    final evolved = await evolve.execute({
      'sentinel_name': 'Reviewer',
      'improvements': 'rename and sharpen',
      'new_name': 'Critic',
      'new_prompt': 'v2',
    });
    expect(evolved, isNot(startsWith('Error:')));

    final result = await revert.execute({
      'sentinel_name': 'Critic',
      'reason': 'undo',
    });

    expect(result, isNot(startsWith('Error:')));
    final restored = (await storage.sentinelRepository.getSentinelById(id))!;
    expect(restored.name, 'Reviewer');
    expect(restored.prompt, 'v1');
  });

  test('别的角色日后用了旧名字，不继承不属于它的快照', () async {
    await createSentinel('Reviewer', 'v1');
    await evolve.execute({
      'sentinel_name': 'Reviewer',
      'improvements': 'rename',
      'new_name': 'Critic',
      'new_prompt': 'v2',
    });
    final newcomer = await createSentinel('Reviewer', 'mine');

    final result = await revert.execute({'sentinel_name': 'Reviewer'});

    expect(result, startsWith('Error: No history snapshots'));
    expect(
      (await storage.sentinelRepository.getSentinelById(newcomer))!.prompt,
      'mine',
    );
  });

  test('snapshot_id 不能穿越到别的目录', () async {
    final id = await createSentinel('Reviewer', 'v1');
    final sentinel = (await storage.sentinelRepository.getSentinelById(id))!;

    for (final snapshotId in ['../../x', '..', 'a/b', r'a\b']) {
      expect(
        await history.load(sentinel, snapshotId),
        isNull,
        reason: snapshotId,
      );
    }
  });
}
