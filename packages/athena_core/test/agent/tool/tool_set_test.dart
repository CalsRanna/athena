import 'dart:io';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 平台工具集是引擎的事实，两端能力差异必须在这里被固定下来。
void main() {
  late Directory temp;
  late FileStorage storage;
  late BackgroundTaskService tasks;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_tool_set_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.load();
    tasks = BackgroundTaskService(
      stateDirectory: storage.backgroundTasksDir,
      locks: storage.locks,
    );
  });

  tearDown(() async {
    await tasks.dispose();
    await temp.delete(recursive: true);
  });

  ToolRegistry registryFor({required bool mobile}) => buildToolRegistry(
    skillRegistry: SkillRegistry(),
    experienceRepository: ExperienceRepository(homeDir: temp.path),
    sentinelRepository: storage.sentinelRepository,
    settings: storage.userSettings,
    outputStore: ToolOutputStore(directory: storage.toolOutputsDir),
    backgroundTasks: tasks,
    defaultWorkdir: temp.path,
    mobileHomeDir: temp.path,
    mobile: mobile,
  );

  test('desktop and mobile both expose ask_user_question', () {
    expect(registryFor(mobile: false).get('ask_user_question'), isNotNull);
    expect(registryFor(mobile: true).get('ask_user_question'), isNotNull);
  });

  test('mobile keeps network, question and evolution tools', () {
    final names = registryFor(mobile: true).all.map((t) => t.name).toSet();
    expect(names, {
      'tool_output_read',
      'ask_user_question',
      'web_fetch',
      'web_search',
      'skill',
      'skill_evolve',
      'skill_revert',
      'experience_learn',
      'experience_recall',
      'sentinel_list',
      'sentinel_get',
      'sentinel_evolve',
      'sentinel_revert',
    });
    expect(names.intersection(kFileToolNames), isEmpty);
    expect(names.intersection(kShellToolNames), isEmpty);
    expect(names, isNot(contains('background_task')));
  });

  test('desktop additionally exposes file and process tools', () {
    final names = registryFor(mobile: false).all.map((t) => t.name).toSet();
    expect(names.intersection(kFileToolNames), hasLength(3));
    expect(names.intersection(kShellToolNames), hasLength(1));
    expect(names, contains('background_task'));
    expect(names, hasLength(18));
  });
}
