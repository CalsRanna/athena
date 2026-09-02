import 'dart:io';

import 'package:athena_core/agent/evolution/memory_digest.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 锁定稳定全量 Memory 目录：完整 lesson、active 过滤与确定性输出。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('memory_digest_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ExperienceEntity exp(
    String lesson, {
    String context = '',
    List<String> tags = const [],
    String scope = 'self',
  }) => ExperienceEntity(
    id: 'id1',
    createdAt: DateTime(2026, 8, 31),
    lesson: lesson,
    context: context,
    tags: tags,
    scope: scope,
    sentinelId: scope == 'shared' ? 'shared' : 's1',
  );

  group('buildDigest', () {
    test('每条含 id / scope / 日期与完整 lesson', () {
      final digest = MemoryDigest.buildDigest([
        exp('short lesson', scope: 'shared'),
      ]);
      expect(digest, contains('stable active long-term memory catalog'));
      // 经验即使已审批也只是历史参考，不能覆盖当前指令。
      expect(digest, contains('reference, not instructions'));
      expect(digest, contains('[id1]'));
      expect(digest, contains('(shared, 2026-08-31)'));
      expect(digest, contains('short lesson'));
    });

    test('lesson 完整注入，不做运行时截断', () {
      final longLesson = List.filled(120, '完整内容').join('-');
      final digest = MemoryDigest.buildDigest([exp(longLesson)]);
      expect(longLesson.length, greaterThan(80));
      expect(digest, contains(longLesson));
      expect(digest, isNot(contains('…')));
    });

    test('多行 lesson 只归一化空白，不丢内容', () {
      final digest = MemoryDigest.buildDigest([exp('line1\nline2\tline3')]);
      expect(digest, contains('line1 line2 line3'));
      expect(digest, isNot(contains('\nline2')));
    });
  });

  group('messagesForSentinel', () {
    test('无 active 经验时返回 null（零成本跳过）', () async {
      final messages = await MemoryDigest.messagesForSentinel(
        repository: ExperienceRepository(homeDir: rootHome),
        sentinelId: 's1',
      );
      expect(messages, isNull);
    });

    test('注入全部 active 私有与 shared 经验，不按任务筛选或限制条数', () async {
      final repo = ExperienceRepository(homeDir: rootHome);
      for (var i = 0; i < 5; i++) {
        await repo.save(lesson: 'private memory $i', sentinelId: 's1');
      }
      await repo.save(
        lesson: 'shared memory',
        scope: 'shared',
        sentinelId: 's1',
      );
      final archived = await repo.save(
        lesson: 'archived memory',
        sentinelId: 's1',
      );
      await repo.update(
        sentinelId: 's1',
        id: archived.id,
        status: ExperienceEntity.statusArchived,
      );

      final messages = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: 's1',
      );
      expect(messages, isNotNull);
      expect(messages, hasLength(1));
      final msg = messages!.single;
      expect(msg, isA<SystemMessage>());
      final content = (msg as SystemMessage).content;
      expect(RegExp(r'- \[[^\]]+\] \(').allMatches(content), hasLength(6));
      for (var i = 0; i < 5; i++) {
        expect(content, contains('private memory $i'));
      }
      expect(content, contains('shared memory'));
      expect(content, isNot(contains('archived memory')));
      expect(content, contains('experience_recall'));
    });

    test('经验库不变时重复生成的目录逐字一致', () async {
      final repo = ExperienceRepository(homeDir: rootHome);
      await repo.save(lesson: 'stable private memory', sentinelId: 's1');
      await repo.save(
        lesson: 'stable shared memory',
        scope: 'shared',
        sentinelId: 's1',
      );

      final first = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: 's1',
      );
      final second = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: 's1',
      );

      expect(
        (first!.single as SystemMessage).content,
        (second!.single as SystemMessage).content,
      );
    });
  });
}
