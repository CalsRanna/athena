import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 并行组里不得有需要审批弹窗的调用：多个审批模态同时
/// 弹出会互相覆盖。`selectParallelCalls` 先用权限预检分级，再看工具的并行声明。
void main() {
  late PermissionStore store;
  late AgentService service;
  late ToolRegistry registry;

  setUp(() {
    store = PermissionStore(); // 只用内存规则
    registry = ToolRegistry()
      ..register(FileReadTool())
      ..register(FileWriteTool());
    service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  tearDown(() => registry.backgroundTasks.dispose());

  ToolCall call(String id, String tool, Map<String, dynamic> args) => ToolCall(
    id: id,
    type: 'function',
    function: FunctionCall(
      name: tool,
      arguments: jsonEncode({'call_description': id, ...args}),
    ),
  );

  List<String> select(
    List<ToolCall> calls, {
    bool bypass = false,
    String? workspace,
  }) => service
      .selectParallelCalls(
        calls,
        runId: 1,
        permissionService: PermissionService(store: store),
        onPermission: (_, _, {reviewReason}) async => true,
        workspace: workspace,
        bypassPermissions: bypass,
      )
      .map((c) => c.id)
      .toList();

  test('需要人工或 AI 审核的调用均串行，避免同时弹出审批', () {
    expect(
      select([
        call('allowed', 'file_read', {'path': '/w/a.txt'}),
        call('needs-approval', 'file_read', {'path': '/elsewhere/b.txt'}),
        call('not-parallel', 'file_write', {'path': '/w/c.txt', 'content': ''}),
      ]),
      isEmpty,
    );
  });

  test('相对路径按工作文件夹解析后再预检，与执行口径一致', () {
    expect(
      select(
        [
          call('relative', 'file_read', {'path': 'a.txt'}),
        ],
        workspace: '/w',
        bypass: true,
      ),
      ['relative'],
    );
  });

  test('bypass 下无需审批的调用可并行，deny 与不可并行的工具仍排除', () {
    store.rules.add(
      const PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/secret',
      ),
    );

    expect(
      select([
        call('free', 'file_read', {'path': '/any/a.txt'}),
        call('denied', 'file_read', {'path': '/secret/key'}),
        call('write', 'file_write', {'path': '/any/b.txt', 'content': ''}),
      ], bypass: true),
      ['free'],
    );
  });

  test('bypass 对旧的模型审批建议不作处理', () {
    expect(
      select([
        call('legacy', 'file_read', {
          'path': '/w/a.txt',
          'approval_recommendation': 'ask',
        }),
      ], bypass: true),
      ['legacy'],
    );
  });
}
