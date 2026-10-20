import 'dart:io';

import 'package:athena_core/agent/memory/memory_capacity.dart';
import 'package:athena_core/agent/memory/memory_digest.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 目录每次 run 全量注入，是唯一没有天然上限的上下文块。这里锁住两件事：
/// 装满时**拒绝新增**（而不是静默丢弃），以及注入端那道兜底确实生效。
void main() {
  ExperienceEntity entity({
    required String id,
    String? lesson,
    DateTime? updatedAt,
    String scope = 'self',
  }) => ExperienceEntity(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    lesson: lesson ?? 'x' * 400,
    scope: scope,
    sentinelId: scope == 'shared' ? 'shared' : '1',
    updatedAt: updatedAt,
  );

  group('预算口径', () {
    test('渲染一条 = 一行，且换行被压平', () {
      final line = MemoryCapacity.renderEntry(
        entity(id: 'abc', lesson: '第一行\n第二行'),
      );

      expect(line, '- [abc] (私有, 2026-01-01) 第一行 第二行');
    });

    test('未写入条目的预估与实际渲染等长（id 与日期定宽）', () {
      final estimated = MemoryCapacity.pendingEntryChars(
        lesson: 'same lesson text',
        shared: false,
      );
      final actual = MemoryCapacity.renderEntry(
        entity(id: 'f' * 36, lesson: 'same lesson text'),
      );

      expect(estimated, actual.length + 1);
    });

    test('shared 与私有只差一个字的来源标记', () {
      expect(
        MemoryCapacity.renderEntry(
          entity(id: 'a', lesson: 'x', scope: 'shared'),
        ),
        contains('(共享, '),
      );
      expect(
        MemoryCapacity.renderEntry(entity(id: 'a', lesson: 'x')),
        contains('(私有, '),
      );
    });

    test('刚好装满不算超限，再多一个字符就超', () {
      final existing = [entity(id: 'a', lesson: 'x' * 100)];
      final remaining =
          MemoryCapacity.maxCatalogChars -
          MemoryCapacity.catalogChars(existing);
      // 条目开销（id、来源、日期、分隔符）是定宽的，剩下的全给 lesson。
      final fixed = MemoryCapacity.pendingEntryChars(lesson: '', shared: false);
      final exactLesson = 'y' * (remaining - fixed);

      expect(
        MemoryCapacity.pendingEntryChars(lesson: exactLesson, shared: false),
        remaining,
      );
      expect(
        MemoryCapacity.exceedsCapacity(
          existing: existing,
          lesson: exactLesson,
          shared: false,
        ),
        isFalse,
        reason: '填满到上限且不超出，应当允许写入',
      );
      expect(
        MemoryCapacity.exceedsCapacity(
          existing: existing,
          lesson: '${exactLesson}y',
          shared: false,
        ),
        isTrue,
      );
    });

    test('withinBudget 保留优先级靠前的条目并报告丢弃数', () {
      final many = [
        for (var i = 0; i < 100; i++)
          entity(
            id: i.toString().padLeft(36, '0'),
            lesson: 'z' * 400,
            updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ]..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));

      final result = MemoryCapacity.withinBudget(many);

      expect(result.dropped, greaterThan(0));
      expect(result.kept, isNotEmpty);
      expect(result.kept.first.id, many.first.id);
      expect(
        MemoryCapacity.catalogChars(result.kept),
        lessThanOrEqualTo(MemoryCapacity.maxCatalogChars),
      );
    });

    test('空集合不丢任何条目', () {
      final result = MemoryCapacity.withinBudget(const []);
      expect(result.kept, isEmpty);
      expect(result.dropped, 0);
    });
  });

  group('写入端拦截', () {
    late Directory temp;
    late ExperienceRepository repo;
    late ExperienceLearnTool tool;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('athena_capacity_');
      repo = ExperienceRepository(homeDir: temp.path);
      tool = ExperienceLearnTool(repository: repo);
    });

    tearDown(() => temp.delete(recursive: true));

    Map<String, dynamic> args(Map<String, dynamic> extra) => {
      'lesson': 'a lesson',
      'call_description': 'record a lesson',
      '_sentinel_id': '1',
      ...extra,
    };

    /// 把集合填到刚好装不下一条新的经验。
    Future<void> fillToCapacity() async {
      final fillers = <String>[];
      while (true) {
        final used = MemoryCapacity.catalogChars(
          fillers.map(
            (lesson) => ExperienceEntity(
              id: 'x' * 36,
              createdAt: DateTime(2026),
              lesson: lesson,
              sentinelId: '1',
            ),
          ),
        );
        if (used +
                MemoryCapacity.pendingEntryChars(lesson: 'new', shared: false) >
            MemoryCapacity.maxCatalogChars) {
          break;
        }
        fillers.add('y' * 400);
      }
      for (var i = 0; i < fillers.length; i++) {
        await repo.save(lesson: fillers[i], sentinelId: '1');
      }
    }

    test('目录已满时拒绝新增，且不产生文件', () async {
      await fillToCapacity();
      final before = (await repo.listForSentinel('1')).length;

      final result = await tool.execute(args({'lesson': 'brand new lesson'}));

      expect(result, startsWith('Error:'));
      expect(result, contains('memory catalog is full'));
      expect(result, contains('Nothing was written'));
      expect((await repo.listForSentinel('1')), hasLength(before));
    });

    test('拒绝信息给出最旧的候选与可执行的下一步', () async {
      await fillToCapacity();

      final result = await tool.execute(args({'lesson': 'brand new lesson'}));

      expect(result, contains('Candidates, oldest first'));
      expect(result, contains('action="archive"'));
    });

    test('归档一条后又能写入', () async {
      await fillToCapacity();
      final oldest = (await repo.listForSentinel('1')).last;

      final blocked = await tool.execute(args({'lesson': 'brand new lesson'}));
      expect(blocked, startsWith('Error:'));

      final archived = await tool.execute(
        args({'action': 'archive', 'experience_id': oldest.id}),
      );
      expect(archived, isNot(startsWith('Error:')));

      final retried = await tool.execute(args({'lesson': 'brand new lesson'}));
      expect(retried, contains('Experience recorded successfully'));
    });

    test('update 与 archive 不受容量限制', () async {
      await fillToCapacity();
      final target = (await repo.listForSentinel('1')).first;

      expect(
        await tool.execute(
          args({'action': 'update', 'experience_id': target.id, 'lesson': 'r'}),
        ),
        isNot(startsWith('Error:')),
      );
      expect(
        await tool.execute(
          args({'action': 'archive', 'experience_id': target.id}),
        ),
        isNot(startsWith('Error:')),
      );
    });
  });

  group('注入端安全网', () {
    late Directory temp;
    late ExperienceRepository repo;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('athena_over_capacity_');
      repo = ExperienceRepository(homeDir: temp.path);
    });

    tearDown(() => temp.delete(recursive: true));

    test('历史超限数据被截断并注明还有多少条', () async {
      // 绕过写入端直接落盘，模拟升级前就存在的超限集合。
      for (var i = 0; i < 60; i++) {
        await repo.save(lesson: 'lesson $i ' * 60, sentinelId: '1');
      }

      final messages = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: '1',
      );
      final text = (messages!.single as SystemMessage).content;

      expect(text.length, lessThan(MemoryCapacity.maxCatalogChars + 500));
      expect(text, contains('因容量上限未列出'));
      expect(text, contains('experience_recall'));
    });

    test('未超限时不出现截断提示', () async {
      await repo.save(lesson: 'short one', sentinelId: '1');

      final text =
          ((await MemoryDigest.messagesForSentinel(
                    repository: repo,
                    sentinelId: '1',
                  ))!.single
                  as SystemMessage)
              .content;

      expect(text, isNot(contains('未列出')));
    });
  });
}
