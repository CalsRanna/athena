import 'package:athena_core/agent/tool/sentinel_get_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

import 'in_memory_sentinel_repository.dart';

/// 锁定 sentinel_get：完整详情（含 prompt 全文）、精确名称、错误引导。
void main() {
  test('返回完整详情并包含 prompt 全文', () async {
    final repo = InMemorySentinelRepository()
      ..sentinels.add(SentinelEntity(
        id: 1,
        name: 'Athena',
        avatar: '⚔️',
        description: '专业冷静的助手',
        prompt: 'PROMPT-FULL-BODY',
        tags: 'assistant',
      ));
    final tool = SentinelGetTool(repository: repo);
    final result = await tool.execute({'sentinel_name': 'Athena'});

    expect(result, contains('**Athena**'));
    expect(result, contains('Name: Athena'));
    expect(result, contains('Avatar: ⚔️'));
    expect(result, contains('Tags: assistant'));
    expect(result, contains('Description: 专业冷静的助手'));
    expect(result, contains('**Prompt:**'));
    expect(result, contains('PROMPT-FULL-BODY'));
  });

  test('未知名字返回错误并引导 sentinel_list', () async {
    final repo = InMemorySentinelRepository();
    final tool = SentinelGetTool(repository: repo);
    final result = await tool.execute({'sentinel_name': 'Nope'});

    expect(result, contains('not found'));
    expect(result, contains('sentinel_list'));
  });

  test('空名字返回参数错误', () async {
    final tool = SentinelGetTool(repository: InMemorySentinelRepository());
    expect(await tool.execute({'sentinel_name': '  '}),
        contains('must not be empty'));
    expect(await tool.execute({}), contains('must not be empty'));
  });

  test('只读平行执行:risk 为 readOnly、executionMode 为 parallel', () {
    final tool = SentinelGetTool(repository: InMemorySentinelRepository());
    expect(tool.risk, ToolRisk.readOnly);
    expect(tool.executionMode, ExecutionMode.parallel);
  });
}
