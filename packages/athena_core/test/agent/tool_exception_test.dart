import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

void main() {
  late _ThrowingFileReadTool tool;
  late ToolRegistry registry;
  late AgentService service;

  setUp(() {
    tool = _ThrowingFileReadTool();
    registry = ToolRegistry()..register(tool);
    service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  tearDown(() => registry.backgroundTasks.dispose());

  Future<ToolCallResultInternal> execute() => service.executeToolCallInternal(
    toolCall: ToolCall(
      id: 'call_1',
      type: 'function',
      function: FunctionCall(
        name: 'file_read',
        arguments: jsonEncode({
          'path': '/tmp/gbk.txt',
          'call_description': 'read a file',
        }),
      ),
    ),
    cancelToken: CancelToken(),
  );

  test('工具抛出的异常作为错误结果交还模型，不终止 run', () async {
    tool.error = const FileSystemException(
      'Failed to decode data using encoding utf-8',
    );

    final result = await execute();

    expect(result.status, ToolResultStatus.executionError);
    expect(result.rawResult, startsWith('Error:'));
    expect(
      result.rawResult,
      contains('Failed to decode data'),
      reason: '模型需要看到失败原因才能换一种做法',
    );
  });

  test('取消异常照常冒泡，由 run 的取消路径收尾', () async {
    tool.error = const CancelledException();

    await expectLater(execute(), throwsA(isA<CancelledException>()));
  });
}

class _ThrowingFileReadTool extends FileReadTool {
  Object error = StateError('unset');

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async => throw error;
}
