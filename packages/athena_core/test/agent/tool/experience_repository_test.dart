import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:test/test.dart';

/// 锁定经验仓库生命周期：update/archive、归档过滤与评分排序。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('experience_repo_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ExperienceRepository newRepo() => ExperienceRepository(homeDir: rootHome);

  group('update', () {
    test('覆盖提供的字段并更新 updatedAt', () async {
      final repo = newRepo();
      final e = await repo.save(
        lesson: 'original lesson',
        context: 'original context',
        tags: ['a'],
        sentinelId: 's1',
      );
      expect(e.updatedAt, isNull);

      final updated = await repo.update(
        sentinelId: 's1',
        id: e.id,
        lesson: 'revised lesson',
      );
      expect(updated, isNotNull);
      expect(updated!.lesson, 'revised lesson');
      expect(updated.context, 'original context'); // 未提供的保持原值
      expect(updated.tags, ['a']);
      expect(updated.updatedAt, isNotNull);
    });

    test('scope 变更迁移文件：self → shared 后旧文件删除', () async {
      final repo = newRepo();
      final e = await repo.save(lesson: 'lesson', sentinelId: 's1');

      final updated = await repo.update(
        sentinelId: 's1',
        id: e.id,
        scope: 'shared',
      );
      expect(updated!.sentinelId, 'shared');

      final file = File('$rootHome/.athena/experiences/s1/${e.id}.json');
      expect(file.existsSync(), isFalse, reason: '旧文件应被删除');
      final sharedFile = File(
        '$rootHome/.athena/experiences/shared/${e.id}.json',
      );
      expect(sharedFile.existsSync(), isTrue);
      // 迁移后可被其他 sentinel 检索到
      final all = await repo.listForSentinel('other');
      expect(all.map((x) => x.id), contains(e.id));
    });

    test('不存在的经验返回 null', () async {
      final repo = newRepo();
      final updated = await repo.update(
        sentinelId: 's1',
        id: 'nope',
        lesson: 'x',
      );
      expect(updated, isNull);
    });
  });

  group('archive 与过滤', () {
    test('archived 经验默认不参与列表与搜索，includeArchived 可见', () async {
      final repo = newRepo();
      final a = await repo.save(
        lesson: 'keep me',
        tags: ['x'],
        sentinelId: 's1',
      );
      final b = await repo.save(
        lesson: 'retired lesson',
        tags: ['x'],
        sentinelId: 's1',
      );
      await repo.update(
        sentinelId: 's1',
        id: b.id,
        status: ExperienceEntity.statusArchived,
      );

      final active = await repo.listForSentinel('s1');
      expect(active.map((x) => x.id), [a.id], reason: 'archived 默认隐藏');

      final withArchived = await repo.listForSentinel(
        's1',
        includeArchived: true,
      );
      expect(withArchived.map((x) => x.id), containsAll([a.id, b.id]));

      final search = await repo.searchForSentinel('s1', 'retired');
      expect(search, isEmpty, reason: 'archived 不参与默认搜索');
    });
  });

  group('评分排序', () {
    test('lesson 命中的旧经验排在 context 命中的新经验之前', () async {
      final repo = newRepo();
      // 先存命中的旧经验（lesson 权重 3）
      await repo.save(
        lesson: 'flutter state management best practices',
        sentinelId: 's1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      // 再存仅 context 命中的新经验（context 权重 1）
      await repo.save(
        lesson: 'unrelated lesson',
        context: 'flutter debugging',
        sentinelId: 's1',
      );

      final results = await repo.searchForSentinel('s1', 'flutter');
      expect(results, hasLength(2));
      expect(
        results.first.lesson,
        contains('best practices'),
        reason: 'lesson 命中权重更高，应排前（即使更旧）',
      );
    });

    test('标签命中参与排序', () async {
      final repo = newRepo();
      await repo.save(lesson: 'lesson a', sentinelId: 's1');
      await repo.save(
        lesson: 'lesson b',
        tags: const ['flutter', 'patterns'],
        sentinelId: 's1',
      );
      final results = await repo.searchForSentinel('s1', 'flutter');
      expect(results.single.lesson, 'lesson b');
    });

    test('连字符标签可被自然语言中的独立单词召回', () async {
      final repo = newRepo();
      await repo.save(
        lesson: 're-read before replacement',
        tags: const ['file-update'],
        sentinelId: 's1',
      );

      final results = await repo.searchForSentinel('s1', 'file update');
      expect(results.single.tags, contains('file-update'));
    });

    test('只重合常见虚词时不召回无关经验', () async {
      final repo = newRepo();
      await repo.save(lesson: 'Use the tool with care', sentinelId: 's1');

      final results = await repo.searchForSentinel(
        's1',
        'Please help me use this',
      );
      expect(results, isEmpty);
    });

    test('中文长句按二元字组召回相关经验', () async {
      final repo = newRepo();
      await repo.save(
        lesson: '修改文件之前必须重新读取最新内容',
        tags: const ['文件修改'],
        sentinelId: 's1',
      );

      final results = await repo.searchForSentinel(
        's1',
        '请帮我安全修改这个文件，先重新读取再替换',
      );
      expect(results.single.lesson, contains('重新读取'));
    });
  });

  test('旧 JSON 无生命周期字段时兼容读取（status 默认 active）', () async {
    final repo = newRepo();
    final dir = Directory('$rootHome/.athena/experiences/s1');
    dir.createSync(recursive: true);
    const legacyJson = {
      'id': 'legacy_1',
      'created_at': '2026-01-01T00:00:00.000',
      'lesson': 'legacy lesson',
      'context': '',
      'tags': <String>[],
      'source': 'auto',
      'scope': 'self',
      'sentinel_id': 's1',
    };
    File(
      '${dir.path}/legacy_1.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(legacyJson));

    final all = await repo.listForSentinel('s1', includeArchived: true);
    expect(all, hasLength(1));
    expect(all.single.status, ExperienceEntity.statusActive);
  });

  test('旧 JSON 的 refuted verdict 读取时自动视为 archived', () async {
    final repo = newRepo();
    final dir = Directory('$rootHome/.athena/experiences/s1');
    dir.createSync(recursive: true);
    final legacyJson = {
      'id': 'legacy_refuted',
      'created_at': '2026-01-01T00:00:00.000',
      'lesson': 'wrong lesson',
      'context': '',
      'tags': <String>[],
      'source': 'auto',
      'scope': 'self',
      'sentinel_id': 's1',
      'status': 'active',
      'user_verdict': 'refuted',
    };
    File(
      '${dir.path}/legacy_refuted.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(legacyJson));

    expect(await repo.listForSentinel('s1'), isEmpty);
    final archived = await repo.listForSentinel('s1', includeArchived: true);
    expect(archived.single.status, ExperienceEntity.statusArchived);
  });
}
