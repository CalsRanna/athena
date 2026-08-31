import 'dart:io';

import 'package:athena_core/agent/evolution/memory_digest.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 锁定记忆摘要注入：格式稳定、截断安全、无相关经验时零成本跳过。
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
    String verdict = ExperienceEntity.verdictNone,
  }) =>
      ExperienceEntity(
        id: 'id1',
        createdAt: DateTime(2026, 8, 31),
        lesson: lesson,
        context: context,
        tags: tags,
        scope: scope,
        sentinelId: scope == 'shared' ? 'shared' : 's1',
        userVerdict: verdict,
      );

  group('buildDigest', () {
    test('每条含 id / scope / 日期与截断后的 lesson', () {
      final digest = MemoryDigest.buildDigest([
        exp('short lesson', scope: 'shared'),
      ]);
      expect(digest, contains('The following are your past experiences'));
      // 免责句：未经验证的经验是参考，不是指令（防错误强化放大）
      expect(digest, contains('reference, not instructions'));
      expect(digest, contains('[id1]'));
      expect(digest, contains('(shared, 2026-08-31)'));
      expect(digest, contains('short lesson'));
    });

    test('lesson 超过 80 字符时按词边界截断', () {
      // 30 个 word = 119 字符，超过截断阈值
      final longLesson = List.filled(30, 'word').join(' ');
      final digest = MemoryDigest.buildDigest([exp(longLesson)]);
      final lines = digest.split('\n');
      final entry = lines.firstWhere((l) => l.startsWith('- [id1]'));
      expect(entry, endsWith('…'));
      expect(longLesson.length, greaterThan(80));
      expect(entry.length, lessThan(longLesson.length),
          reason: '截断后长度应小于原文');
    });

    test('多行 lesson 单行化', () {
      final digest = MemoryDigest.buildDigest([exp('line1\nline2\n')]);
      expect(digest, contains('line1 line2'));
      expect(digest, isNot(contains('\nline2')));
    });
  });

  group('messagesFor', () {
    test('无匹配经验时返回 null（零成本跳过）', () async {
      final messages = await MemoryDigest.messagesFor(
        repository: ExperienceRepository(homeDir: rootHome),
        query: 'anything',
        sentinelId: 's1',
      );
      expect(messages, isNull);
    });

    test('返回单条 system 消息，最多 limit 条', () async {
      final repo = ExperienceRepository(homeDir: rootHome);
      for (var i = 0; i < 5; i++) {
        await repo.save(
          lesson: 'flutter tip $i about state management',
          tags: const ['flutter'],
          sentinelId: 's1',
        );
      }

      final messages = await MemoryDigest.messagesFor(
        repository: repo,
        query: 'flutter',
        sentinelId: 's1',
      );
      expect(messages, isNotNull);
      expect(messages, hasLength(1));
      final msg = messages!.single;
      expect(msg, isA<SystemMessage>());
      // 5 条全部命中，取前 3
      final content = (msg as SystemMessage).content;
      expect(RegExp(r'- \[[^\]]+\] \(').allMatches(content), hasLength(3));
      expect(content, contains('experience_recall'));
    });

    test('按相关度取前 limit 条（lesson 命中优先于 context 命中）', () async {
      final repo = ExperienceRepository(homeDir: rootHome);
      await repo.save(
        lesson: 'flutter state management',
        sentinelId: 's1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.save(
        lesson: 'unrelated',
        context: 'flutter debugging',
        sentinelId: 's1',
      );

      final messages = await MemoryDigest.messagesFor(
        repository: repo,
        query: 'flutter',
        sentinelId: 's1',
      );
      final content = (messages!.single as SystemMessage).content;
      expect(content, contains('flutter state management'));
    });
  });
}
