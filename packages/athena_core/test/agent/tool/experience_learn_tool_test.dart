import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 经验写入是模型的长期记忆入口：可见范围、重复写入与来源标注错了，
/// 后续所有对话都会带着错误的记忆。
void main() {
  late Directory temp;
  late ExperienceRepository repo;
  late ExperienceLearnTool tool;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_learn_');
    repo = ExperienceRepository(homeDir: temp.path);
    tool = ExperienceLearnTool(repository: repo);
  });

  tearDown(() => temp.delete(recursive: true));

  Map<String, dynamic> args(Map<String, dynamic> extra) => {
    'lesson': 'a lesson',
    'durability': 'long_term',
    'reuse_reason': 'Future builds under the same stable constraint.',
    'evidence': 'The controlled build check passed.',
    'confidence': 0.95,
    'call_description': 'record a lesson',
    '_sentinel_id': '1',
    ...extra,
  };

  test('主动记录和反思的新增、修订都拒绝不满足长期门槛的参数', () async {
    final original = await repo.save(lesson: 'original', sentinelId: '1');
    for (final source in ['auto', 'reflection']) {
      for (final action in ['create', 'update']) {
        for (final invalid in <Map<String, dynamic>>[
          {'durability': null},
          {'durability': 'session_only'},
          {'reuse_reason': '  '},
          {'reuse_reason': 123},
          {'evidence': ''},
          {'evidence': null},
          {'confidence': null},
          {'confidence': '0.95'},
          {'confidence': 0.89},
          {'confidence': 1.01},
          {'confidence': double.nan},
          {'confidence': double.infinity},
        ]) {
          final result = await tool.execute(
            args({
              'durability': 'long_term',
              'reuse_reason': 'Future builds under the same stable constraint.',
              'evidence': 'The controlled build check passed.',
              'confidence': 0.95,
              'action': action,
              if (action == 'update') 'experience_id': original.id,
              '_experience_source': source,
              ...invalid,
            }),
          );
          expect(
            result,
            startsWith('Error:'),
            reason: '$source $action $invalid',
          );
          expect(
            (await repo.listForSentinel('1')).single.toJson(),
            original.toJson(),
          );
        }
      }
    }
  });

  test('归档无需复用理由或验证依据', () async {
    final original = await repo.save(lesson: 'obsolete', sentinelId: '1');
    final result = await tool.execute({
      '_sentinel_id': '1',
      'action': 'archive',
      'experience_id': original.id,
    });
    expect(result, contains('Experience archived'));
    expect(await repo.listForSentinel('1'), isEmpty);
  });

  test('默认写入 self 作用域，来源为 auto', () async {
    await tool.execute(args({}));

    final saved = (await repo.listPrivate('1')).single;
    expect(saved.scope, 'self');
    expect(saved.source, 'auto');
    expect(saved.context, contains('长期复用理由：Future builds'));
    expect(saved.context, contains('验证依据：The controlled build check passed.'));
  });

  test('长期偏好可使用用户陈述作依据，置信度边界可写入', () async {
    for (final confidence in [0.9, 1.0]) {
      final result = await tool.execute(
        args({
          'lesson': '偏好 $confidence',
          'reuse_reason': '后续解释技术问题时沿用用户的沟通偏好。',
          'evidence': '用户明确说今后的技术解释都先给简短结论。',
          'confidence': confidence,
        }),
      );
      expect(result, contains('recorded successfully'));
    }
  });

  test('修订时保存新依据，未提供 context 则保留原支持信息', () async {
    final original = await repo.save(
      lesson: 'original',
      context: 'original conditions',
      sentinelId: '1',
    );
    await tool.execute(
      args({
        'action': 'update',
        'experience_id': original.id,
        'evidence': 'new verification',
      }),
    );
    final updated = (await repo.listForSentinel('1')).single;
    expect(updated.context, startsWith('original conditions\n'));
    expect(updated.context, contains('验证依据：new verification'));
  });

  test('scope=shared 写入共享目录，sentinel 记为 shared', () async {
    await tool.execute(args({'scope': 'shared'}));

    expect((await repo.listShared()).single.sentinelId, 'shared');
    expect(await repo.listPrivate('1'), isEmpty);
  });

  test('完全相同的 lesson 不会重复写入', () async {
    await tool.execute(args({}));
    final second = await tool.execute(args({'lesson': '  A LESSON  '}));

    expect(second, contains('already exists'));
    expect(await repo.listForSentinel('1'), hasLength(1));
  });

  test('超过长度上限的 lesson 被拒绝，不产生文件', () async {
    final tooLong = 'x' * (ExperienceEntity.maxLessonLength + 1);

    final result = await tool.execute(args({'lesson': tooLong}));

    expect(result, startsWith('Error:'));
    expect(await repo.listForSentinel('1'), isEmpty);
  });

  test('update 修订既有经验，archive 保留文件但退出检索', () async {
    final created = await tool.execute(args({}));
    final id = (await repo.listPrivate('1')).single.id;

    final updated = await tool.execute(
      args({'action': 'update', 'experience_id': id, 'lesson': 'revised'}),
    );
    expect(updated, isNot(startsWith('Error:')));
    expect((await repo.listPrivate('1')).single.lesson, 'revised');

    final archived = await tool.execute(
      args({'action': 'archive', 'experience_id': id}),
    );
    expect(archived, isNot(startsWith('Error:')));
    expect(await repo.listForSentinel('1'), isEmpty);
    expect(
      (await repo.listForSentinel('1', includeArchived: true)).single.status,
      ExperienceEntity.statusArchived,
    );
    expect(created, contains('Experience recorded successfully'));
  });

  test('create 携带 experience_id 被拒绝，避免误改既有经验', () async {
    final result = await tool.execute(args({'experience_id': 'some-id'}));

    expect(result, contains('must be omitted'));
    expect(await repo.listForSentinel('1'), isEmpty);
  });

  test('检索按 lesson / tags / context 命中，且只在本角色可见范围内', () async {
    await tool.execute(args({'lesson': 'flutter 布局溢出', 'tags': 'ui, layout'}));
    await tool.execute(args({'lesson': '另一个角色的私有经验', '_sentinel_id': '2'}));

    final recall = ExperienceRecallTool(repository: repo);
    final result = await recall.execute({
      'query': 'layout',
      'call_description': 'recall layout lessons',
      '_sentinel_id': '1',
    });

    expect(result, contains('flutter 布局溢出'));
    expect(result, isNot(contains('另一个角色的私有经验')));
  });

  test('引擎注入的来源会写进实体，模型无法通过参数伪造', () async {
    final registry = ToolRegistry()..register(tool);
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    addTearDown(() => registry.backgroundTasks.dispose());

    // 模型自己填的 `_experience_source` 不会生效：该键在权限门之后由引擎
    // 覆盖写入，且不在参数 schema 里。
    await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'call_1',
        type: 'function',
        function: FunctionCall(
          name: 'experience_learn',
          arguments: jsonEncode(
            args({
              'lesson': 'from reflection',
              'call_description': 'record a lesson',
              '_experience_source': 'forged',
              '_chat_id': 'forged-chat',
              '_message_id': 'forged-message',
            }),
          ),
        ),
      ),
      cancelToken: CancelToken(),
      sentinelId: '1',
      experienceSource: 'reflection',
      chatId: 'source-chat',
      messageId: 'source-message',
    );

    final saved = (await repo.listPrivate('1')).single;
    expect(saved.source, 'reflection');
    expect(saved.sourceChatId, 'source-chat');
    expect(saved.sourceMessageId, 'source-message');
    final recalled = await ExperienceRecallTool(
      repository: repo,
    ).execute({'_sentinel_id': '1', 'query': saved.id});
    expect(recalled, contains('Source chat: source-chat'));
    expect(recalled, contains('Source message: source-message'));
  });

  test('宿主未提供来源时，不接受模型伪造的会话和消息标识', () async {
    final registry = ToolRegistry()..register(tool);
    addTearDown(() => registry.backgroundTasks.dispose());
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'call_1',
        type: 'function',
        function: FunctionCall(
          name: 'experience_learn',
          arguments: jsonEncode(
            args({
              'lesson': 'without a source',
              'call_description': 'record a lesson',
              '_chat_id': 'forged-chat',
              '_message_id': 'forged-message',
            }),
          ),
        ),
      ),
      cancelToken: CancelToken(),
      sentinelId: '1',
    );
    final saved = (await repo.listPrivate('1')).single;
    expect(saved.source, 'auto');
    expect(saved.sourceChatId, isNull);
    expect(saved.sourceMessageId, isNull);
  });
}
