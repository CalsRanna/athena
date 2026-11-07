import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/memory/memory_digest.dart';
import 'package:athena_core/agent/memory/reflection.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 目录每次 run 都会进上下文：内容与顺序必须稳定（否则破坏 prompt 缓存），
/// 且不能把归档项重新带回来。反思只在可归因的失败上触发。
void main() {
  group('MemoryDigest', () {
    late Directory temp;
    late ExperienceRepository repo;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('athena_digest_');
      repo = ExperienceRepository(homeDir: temp.path);
    });

    tearDown(() => temp.delete(recursive: true));

    test('无经验时不注入空段', () async {
      expect(
        await MemoryDigest.messagesForSentinel(
          repository: repo,
          sentinelId: '1',
        ),
        isNull,
      );
    });

    test('目录含私有与共享经验，且标注来源与日期', () async {
      await repo.save(lesson: '私有教训', sentinelId: '1');
      await repo.save(lesson: '共享偏好', scope: 'shared', sentinelId: '1');

      final messages = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: '1',
      );
      final text = (messages!.single as SystemMessage).content;

      expect(text, contains('私有教训'));
      expect(text, contains('共享偏好'));
      expect(text, contains('私有'));
      expect(text, contains('共享'));
      expect(text, contains('参考资料'));
    });

    test('归档经验不出现在目录里', () async {
      final created = await repo.save(lesson: '作废的教训', sentinelId: '1');
      await repo.update(
        sentinelId: '1',
        id: created.id,
        status: ExperienceEntity.statusArchived,
      );

      expect(
        await MemoryDigest.messagesForSentinel(
          repository: repo,
          sentinelId: '1',
        ),
        isNull,
      );
    });

    test('内容不变时目录逐字节一致，保护 prompt prefix cache', () async {
      for (var i = 0; i < 5; i++) {
        await repo.save(lesson: 'lesson $i', sentinelId: '1');
      }

      final first = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: '1',
      );
      final second = await MemoryDigest.messagesForSentinel(
        repository: repo,
        sentinelId: '1',
      );

      expect(
        (first!.single as SystemMessage).content,
        (second!.single as SystemMessage).content,
      );
    });

    test('lesson 里的换行被压成单行，一条经验不会占用多行', () async {
      await repo.save(lesson: '第一行\n第二行', sentinelId: '1');

      final text =
          ((await MemoryDigest.messagesForSentinel(
                    repository: repo,
                    sentinelId: '1',
                  ))!.single
                  as SystemMessage)
              .content;

      expect(text, contains('第一行 第二行'));
    });

    test('近期被修订过的经验排在前面（容量不足时优先保留）', () async {
      final older = await repo.save(lesson: 'older lesson', sentinelId: '1');
      await repo.save(lesson: 'newer lesson', sentinelId: '1');
      await repo.update(
        sentinelId: '1',
        id: older.id,
        lesson: 'older lesson reinforced',
      );

      final text =
          ((await MemoryDigest.messagesForSentinel(
                    repository: repo,
                    sentinelId: '1',
                  ))!.single
                  as SystemMessage)
              .content;

      expect(
        text.indexOf('reinforced'),
        lessThan(text.indexOf('newer lesson')),
        reason: '最近被强化过的经验应先保留',
      );
    });
  });

  test('反思工具摘录限制长度并保留验证输出末尾', () {
    final result = ReflectionPrompt.toolResult(
      tool: 'bash',
      arguments: 'x' * 2000,
      status: ToolResultStatus.success,
      result: 'start\n${'log\n' * 1000}All tests passed.',
    );
    expect((result['arguments'] as String).length, lessThan(1100));
    expect((result['result'] as String).length, lessThan(2100));
    expect(result['result'], startsWith('start\n'));
    expect(result['result'], contains('[truncated]'));
    expect(result['result'], endsWith('All tests passed.'));
  });

  group('ReflectionPolicy', () {
    AgentRunOutcome outcome(
      List<ToolFailure> failures, {
      AgentRunTermination termination = AgentRunTermination.completed,
    }) => AgentRunOutcome(
      termination: termination,
      iterations: 3,
      toolFailures: failures,
    );

    test('同一工具失败两次才反思', () {
      expect(
        ReflectionPolicy.shouldReflect(
          outcome([
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.executionError,
              message: 'boom',
            ),
          ]),
        ),
        isFalse,
      );
      expect(
        ReflectionPolicy.shouldReflect(
          outcome([
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.executionError,
              message: 'boom',
            ),
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.executionError,
              message: 'boom again',
            ),
          ]),
        ),
        isTrue,
      );
    });

    test('单次失败铺在不同工具上不构成可归因失败', () {
      expect(
        ReflectionPolicy.shouldReflect(
          outcome([
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.executionError,
              message: 'x',
            ),
            const ToolFailure(
              toolName: 'file_read',
              status: ToolResultStatus.executionError,
              message: 'y',
            ),
          ]),
        ),
        isFalse,
      );
    });

    test('被权限拦截的失败不计入，用户取消与出错的 run 也不反思', () {
      expect(
        ReflectionPolicy.shouldReflect(
          outcome([
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.blocked,
              message: 'denied',
            ),
            const ToolFailure(
              toolName: 'bash',
              status: ToolResultStatus.blocked,
              message: 'denied again',
            ),
          ]),
        ),
        isFalse,
      );
      for (final termination in [
        AgentRunTermination.cancelled,
        AgentRunTermination.error,
      ]) {
        expect(
          ReflectionPolicy.shouldReflect(
            outcome([
              const ToolFailure(
                toolName: 'bash',
                status: ToolResultStatus.executionError,
                message: 'x',
              ),
              const ToolFailure(
                toolName: 'bash',
                status: ToolResultStatus.executionError,
                message: 'y',
              ),
            ], termination: termination),
          ),
          isFalse,
          reason: termination.name,
        );
      }
    });
  });

  group('ReflectionProposal', () {
    String proposal(Map<String, dynamic> changes) => jsonEncode({
      'should_learn': true,
      'action': 'create',
      'durability': 'long_term',
      'reuse_reason': 'Future builds use the same verified SDK constraint.',
      'evidence': 'The build passed with the required SDK version.',
      'lesson': 'Use the SDK version required by this toolchain.',
      'confidence': 0.95,
      ...changes,
    });

    test('高置信度的临时经验、缺少复用理由或验证依据都不记录', () {
      for (final changes in <Map<String, dynamic>>[
        {'durability': 'session_only', 'confidence': 1.0},
        {'durability': null},
        {'reuse_reason': '  '},
        {'evidence': ''},
        {'confidence': 0.89},
      ]) {
        expect(ReflectionProposal.tryParse(proposal(changes)), isNull);
      }
    });

    test('只能修订提供的候选，保留作用域并把依据交给标准工具审批', () {
      final text = proposal({
        'action': 'update',
        'experience_id': 'known',
        'scope': 'self',
      });
      expect(ReflectionProposal.tryParse(text), isNull);
      final parsed = ReflectionProposal.tryParse(
        text,
        allowedExperienceIds: {'known'},
      )!;
      final args = parsed.toToolArguments();
      expect(args['action'], 'update');
      expect(args['experience_id'], 'known');
      expect(args.containsKey('scope'), isFalse);
      expect(args['reuse_reason'], contains('Future builds'));
      expect(args['evidence'], contains('The build passed'));
      expect(args['durability'], 'long_term');
      expect(args['confidence'], 0.95);
      expect(
        ReflectionProposal.tryParse(proposal({'action': 'archive'})),
        isNull,
      );
    });
    test('低置信度、空 lesson 或显式不学都不产生提案', () {
      expect(
        ReflectionProposal.tryParse(proposal({'confidence': 0.5})),
        isNull,
      );
      expect(ReflectionProposal.tryParse(proposal({'lesson': '  '})), isNull);
      expect(ReflectionProposal.tryParse('{"should_learn":false}'), isNull);
    });

    test('超长 lesson 与非法 scope 的处理', () {
      final tooLong = 'x' * (ExperienceEntity.maxLessonLength + 1);
      expect(
        ReflectionProposal.tryParse(proposal({'lesson': tooLong})),
        isNull,
      );

      final parsed = ReflectionProposal.tryParse(proposal({'scope': 'global'}));
      expect(parsed!.scope, 'self');
    });

    test('提案转成标准工具调用参数，带上调用说明', () {
      final parsed = ReflectionProposal.tryParse(
        proposal({
          'lesson': 'x',
          'context': 'c',
          'tags': ['a', 'b'],
        }),
      )!;

      final args = parsed.toToolArguments();

      expect(args['action'], 'create');
      expect(args['lesson'], 'x');
      expect(args['tags'], 'a, b');
      expect(args['scope'], 'self');
      expect(args['call_description'], isNotEmpty);
    });
  });
}
