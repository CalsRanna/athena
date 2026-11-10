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
  late Directory root;
  late ToolRegistry registry;
  late AgentService service;
  late File png;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_tool_images_');
    png = File('${root.path}/shot.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
          'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );
    registry = ToolRegistry()..register(FileReadTool());
    service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  tearDown(() {
    registry.backgroundTasks.dispose();
    root.deleteSync(recursive: true);
  });

  Future<ToolCallResultInternal> read({required bool supportsVision}) =>
      service.executeToolCallInternal(
        toolCall: ToolCall(
          id: 'call_1',
          type: 'function',
          function: FunctionCall(
            name: 'file_read',
            arguments: jsonEncode({
              'path': png.path,
              'call_description': 'read a screenshot',
            }),
          ),
        ),
        cancelToken: CancelToken(),
        supportsVision: supportsVision,
      );

  test('视觉模型拿到图片载荷', () async {
    final result = await read(supportsVision: true);

    expect(result.status, ToolResultStatus.success);
    expect(result.images, hasLength(1));
    expect(result.images.single.mediaType, 'image/png');
    // 事件是协调层落盘的来源；图片必须随事件一起交出去。
    expect(result.event.images.single.mediaType, 'image/png');
  });

  test('非视觉模型收到明确说明，而不是一张它读不懂的图片', () async {
    final result = await read(supportsVision: false);

    expect(result.status, ToolResultStatus.executionError);
    expect(result.images, isEmpty);
    expect(result.rawResult, contains('does not support image input'));
  });
}
