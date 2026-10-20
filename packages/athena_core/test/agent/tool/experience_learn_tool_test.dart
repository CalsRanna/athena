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
    'call_description': 'record a lesson',
    '_sentinel_id': '1',
    ...extra,
  };

  test('默认写入 self 作用域，来源为 auto', () async {
    await tool.execute(args({}));

    final saved = (await repo.listPrivate('1')).single;
    expect(saved.scope, 'self');
    expect(saved.source, 'auto');
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
          arguments: jsonEncode({
            'lesson': 'from reflection',
            'call_description': 'record a lesson',
            '_experience_source': 'forged',
          }),
        ),
      ),
      cancelToken: CancelToken(),
      sentinelId: '1',
      experienceSource: 'reflection',
    );

    expect((await repo.listPrivate('1')).single.source, 'reflection');
  });
}
