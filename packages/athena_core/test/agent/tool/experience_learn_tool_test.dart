import 'dart:io';

import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:test/test.dart';

/// 锁定 experience_learn 的生命周期行为（create/update/archive）
/// 与权限标记（dangerous —— 持久写入必须走现有审批链路）。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('experience_learn_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ExperienceLearnTool newLearnTool() =>
      ExperienceLearnTool(repository: ExperienceRepository(homeDir: rootHome));

  ExperienceRecallTool newRecallTool() =>
      ExperienceRecallTool(repository: ExperienceRepository(homeDir: rootHome));

  test('写入标记为 dangerous，读取仍为 readOnly', () {
    expect(newLearnTool().risk, ToolRisk.dangerous);
    expect(newRecallTool().risk, ToolRisk.readOnly);
  });

  test('create 为默认动作，记录成功后 recall 可检索到', () async {
    final tool = newLearnTool();
    final result = await tool.execute({
      'lesson': 'Always verify the API contract before coding',
      'context': 'Building a Flutter widget',
      'tags': 'flutter, api',
      '_sentinel_id': 's1',
    });
    expect(result, contains('Experience recorded successfully'));
    expect(result, contains('scope: self'));

    final recall = await newRecallTool().execute({
      'query': 'flutter',
      '_sentinel_id': 's1',
    });
    expect(recall, contains('Always verify the API contract'));
  });

  test('create 时携带 experience_id 报错（语义冲突）', () async {
    final tool = newLearnTool();
    final result = await tool.execute({
      'lesson': 'x',
      'experience_id': 'existing_1',
      '_sentinel_id': 's1',
    });
    expect(result, contains('Error'));
    expect(result, contains('"update"'));
  });

  test('create 时 lesson 为空报错', () async {
    final tool = newLearnTool();
    final result = await tool.execute({'lesson': '  ', '_sentinel_id': 's1'});
    expect(result, contains('lesson must not be empty'));
  });

  test('create/update 拒绝超过 500 字符的 lesson', () async {
    final tool = newLearnTool();
    final tooLong = 'x' * (ExperienceEntity.maxLessonLength + 1);
    final createResult = await tool.execute({
      'lesson': tooLong,
      '_sentinel_id': 's1',
    });
    expect(createResult, contains('must not exceed 500 characters'));

    await tool.execute({'lesson': 'original', '_sentinel_id': 's1'});
    final stored = await ExperienceRepository(
      homeDir: rootHome,
    ).listForSentinel('s1');
    final updateResult = await tool.execute({
      'action': 'update',
      'experience_id': stored.single.id,
      'lesson': tooLong,
      '_sentinel_id': 's1',
    });
    expect(updateResult, contains('must not exceed 500 characters'));
    final unchanged = await ExperienceRepository(
      homeDir: rootHome,
    ).listForSentinel('s1');
    expect(unchanged.single.lesson, 'original');
  });

  test('lesson schema 向模型声明 500 字符上限', () {
    final lessonSchema =
        newLearnTool().parameters['properties']['lesson']
            as Map<String, dynamic>;
    expect(lessonSchema['maxLength'], ExperienceEntity.maxLessonLength);
  });

  test('相同 lesson 不重复创建', () async {
    final tool = newLearnTool();
    const args = {
      'lesson': 'Read the file before editing',
      '_sentinel_id': 's1',
    };
    await tool.execute(args);
    final duplicate = await tool.execute(args);

    expect(duplicate, contains('already exists'));
    final all = await ExperienceRepository(
      homeDir: rootHome,
    ).listForSentinel('s1');
    expect(all, hasLength(1));
  });

  test('update 修正经验内容，未提供字段保持原值', () async {
    final learn = newLearnTool();
    await learn.execute({
      'lesson': 'old wrong lesson',
      'context': 'ctx',
      '_sentinel_id': 's1',
    });
    final all = await ExperienceRepository(
      homeDir: rootHome,
    ).listForSentinel('s1');
    final id = all.single.id;

    final result = await learn.execute({
      'action': 'update',
      'experience_id': id,
      'lesson': 'corrected lesson',
      '_sentinel_id': 's1',
    });
    expect(result, contains('Experience updated successfully'));

    final after = await newRecallTool().execute({
      'query': 'corrected',
      '_sentinel_id': 's1',
    });
    expect(after, contains('corrected lesson'));
    expect(after, isNot(contains('old wrong lesson')));
  });

  test('update 无 experience_id 报错', () async {
    final tool = newLearnTool();
    final result = await tool.execute({
      'action': 'update',
      'lesson': 'x',
      '_sentinel_id': 's1',
    });
    expect(result, contains('experience_id is required'));
  });

  test('archive 后默认 recall 不再返回', () async {
    final learn = newLearnTool();
    await learn.execute({
      'lesson': 'lesson to retire',
      'tags': 'retire-me',
      '_sentinel_id': 's1',
    });
    final all = await ExperienceRepository(
      homeDir: rootHome,
    ).listForSentinel('s1');
    final id = all.single.id;

    final result = await learn.execute({
      'action': 'archive',
      'experience_id': id,
      '_sentinel_id': 's1',
    });
    expect(result, contains('Experience archived'));

    final recall = await newRecallTool().execute({
      'query': 'retire-me',
      '_sentinel_id': 's1',
    });
    expect(recall, contains('No active experiences found'));

    // include_archived 时仍可见并带标记
    final withArchived = await newRecallTool().execute({
      'query': 'retire-me',
      'include_archived': true,
      '_sentinel_id': 's1',
    });
    expect(withArchived, contains('[archived]'));
  });

  test('未知 action 报错', () async {
    final tool = newLearnTool();
    final result = await tool.execute({
      'action': 'delete',
      'lesson': 'x',
      '_sentinel_id': 's1',
    });
    expect(result, contains('Unknown action'));
  });

  test('scope=shared 写入后所有 sentinel 可见', () async {
    final learn = newLearnTool();
    await learn.execute({
      'lesson': 'User prefers concise answers',
      'scope': 'shared',
      '_sentinel_id': 's1',
    });

    final recall = await newRecallTool().execute({
      'query': 'concise',
      '_sentinel_id': 'other-sentinel',
    });
    expect(recall, contains('User prefers concise answers'));
    expect(recall, contains('(shared)'));
  });
}
