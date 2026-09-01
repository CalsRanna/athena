import 'package:athena_core/agent/tool/sentinel_list_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

import 'in_memory_sentinel_repository.dart';

/// 锁定 sentinel_list：轻量元数据（不含 prompt）、稳定排序、空库提示。
void main() {
  test('空仓库返回提示信息', () async {
    final tool = SentinelListTool(repository: InMemorySentinelRepository());
    final result = await tool.execute({});
    expect(result, contains('No sentinels found'));
  });

  test('列出元数据且不含 prompt 全文', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.addAll([
        SentinelEntity(
          id: 1,
          name: 'Athena',
          avatar: '⚔️',
          description: '专业冷静的助手',
          prompt: 'TOP SECRET PROMPT',
          tags: 'assistant,agent',
        ),
        SentinelEntity(id: 2, name: 'Translator', prompt: 'TRANSLATOR PROMPT'),
      ]);
    final tool = SentinelListTool(repository: repo);
    final result = await tool.execute({});

    expect(result, contains('Available sentinels (2)'));
    expect(result, contains('**Athena**'));
    expect(result, contains('**Translator**'));
    expect(result, contains('Description: 专业冷静的助手'));
    expect(result, contains('Tags: assistant, agent'));
    expect(result, contains('Avatar: ⚔️'));
    // 列表绝不携带 prompt 全文（token 控制）
    expect(result, isNot(contains('TOP SECRET PROMPT')));
    expect(result, isNot(contains('TRANSLATOR PROMPT')));
    // 引导后续查询
    expect(result, contains('sentinel_get'));
  });

  test('按名称排序输出稳定', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.addAll([
        SentinelEntity(id: 1, name: 'Zed', prompt: ''),
        SentinelEntity(id: 2, name: 'Alpha', prompt: ''),
      ]);
    final result = await SentinelListTool(repository: repo).execute({});

    expect(result.indexOf('**Alpha**') < result.indexOf('**Zed**'), isTrue);
  });

  test('隐藏的预设角色标注 hidden preset', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(
        id: 1,
        name: 'HiddenRole',
        prompt: '',
        isPreset: true,
      ));
    final tool = SentinelListTool(repository: repo);
    final result = await tool.execute({});

    expect(result, contains('**HiddenRole** (hidden preset)'));
  });

  test('多行描述折叠为单行', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(
        id: 1,
        name: 'A',
        description: 'line1\nline2',
        prompt: '',
      ));
    final tool = SentinelListTool(repository: repo);
    final result = await tool.execute({});

    expect(result, contains('Description: line1 line2'));
    expect(result, isNot(contains('\nline2')));
  });

  test('只读平行执行:risk 为 readOnly、executionMode 为 parallel', () async {
    final tool = SentinelListTool(repository: InMemorySentinelRepository());
    expect(tool.risk, ToolRisk.readOnly);
    expect(tool.executionMode, ExecutionMode.parallel);
  });
}
