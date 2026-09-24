import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/agent/tool/sentinel_get_tool.dart';
import 'package:athena_core/agent/tool/sentinel_list_tool.dart';
import 'package:athena_core/agent/tool/sentinel_revert_tool.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late FileStorage storage;
  late SentinelHistoryStore history;
  final legacy = <String, dynamic>{
    'id': 7,
    'name': 'Reviewer',
    'avatar': 'legacy-avatar',
    'description': 'Review code',
    'prompt': 'Find correctness issues.',
    'tags': 'code,review',
    'is_preset': 0,
  };
  final currentFields = Map<String, dynamic>.of(legacy)..remove('avatar');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_sentinel_legacy_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    history = SentinelHistoryStore(homeDir: temp.path);
    await storage.root.create(recursive: true);
    await storage.sentinelsFile.writeAsString(jsonEncode([legacy]));
  });

  tearDown(() => temp.delete(recursive: true));

  test('旧角色和备份保留全部有效字段，编辑后不再写出头像', () async {
    final repository = storage.sentinelRepository;
    final sentinel = (await repository.getAllSentinels()).single;
    expect(sentinel.toJson(), currentFields);

    await repository.updateSentinel(sentinel.copyWith(description: 'Updated'));
    final saved =
        (jsonDecode(await storage.sentinelsFile.readAsString()) as List).single;
    expect(saved, {...currentFields, 'description': 'Updated'});

    await repository.importSentinels([SentinelEntity.fromJson(legacy)]);
    expect((await repository.getSentinelById(7))!.toJson(), currentFields);
    final listing = await SentinelListTool(repository: repository).execute({});
    final details = await SentinelGetTool(
      repository: repository,
    ).execute({'sentinel_name': 'Reviewer'});
    expect(listing, contains('Review code'));
    expect(details, contains('Find correctness issues.'));
    expect('$listing\n$details', isNot(contains('Avatar')));
    expect('$listing\n$details', isNot(contains('legacy-avatar')));
  });

  test('旧头像快照仍可回滚，后续演进快照只保存有效字段', () async {
    final snapshot = File(
      p.join(
        temp.path,
        '.athena',
        'sentinels',
        'Reviewer',
        'history',
        'legacy.json',
      ),
    );
    await snapshot.parent.create(recursive: true);
    await snapshot.writeAsString(
      jsonEncode({
        'snapshot_id': 'legacy',
        'saved_at': '2025-01-01T00:00:00Z',
        'reason': 'Older version',
        'sentinel': {...legacy, 'prompt': 'Previous instructions.'},
      }),
    );
    final repository = storage.sentinelRepository;
    final reverted = await SentinelRevertTool(
      repository: repository,
      historyStore: history,
    ).execute({'sentinel_name': 'Reviewer', 'snapshot_id': 'legacy'});
    expect(reverted, isNot(startsWith('Error:')));
    expect((await repository.getSentinelById(7))!.toJson(), {
      ...currentFields,
      'prompt': 'Previous instructions.',
    });

    final evolve = SentinelEvolveTool(
      repository: repository,
      historyStore: history,
    );
    expect(evolve.parameters['properties'], isNot(contains('new_avatar')));
    final result = await evolve.execute({
      'sentinel_name': 'Reviewer',
      'improvements': 'Clarify instructions',
      'new_prompt': 'Improved instructions.',
    });
    expect(result, isNot(startsWith('Error:')));
    expect((await repository.getSentinelById(7))!.toJson(), {
      ...currentFields,
      'prompt': 'Improved instructions.',
    });
    final snapshots = await history.list('Reviewer');
    expect(snapshots, hasLength(3));
    for (final meta in snapshots.where((meta) => meta.id != 'legacy')) {
      final file = File(p.join(snapshot.parent.path, '${meta.id}.json'));
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(data['sentinel'], isNot(contains('avatar')));
      expect((await history.load('Reviewer', meta.id))!.id, 7);
    }
  });
}
