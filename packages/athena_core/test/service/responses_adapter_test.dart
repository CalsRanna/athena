import 'package:athena_core/service/responses_adapter.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 覆盖 Responses 适配器的两侧映射。
///
/// 关键断言不是「调用了哪个方法」，而是：归一流能被 Athena 上层的
/// [ChatStreamAccumulator] 直接消费（上层不感知协议差异）、以及表达不了的
/// 内容会显式失败而不是被静默丢弃。
void main() {
  ChatCompletionCreateRequest chatRequest({
    List<ChatMessage>? messages,
    List<Tool>? tools,
    double? temperature,
    ReasoningEffort? reasoningEffort,
    ResponseFormat? responseFormat,
  }) {
    return ChatCompletionCreateRequest(
      model: 'gpt-5',
      messages: messages ?? [ChatMessage.user('hi')],
      tools: tools,
      temperature: temperature,
      reasoningEffort: reasoningEffort,
      responseFormat: responseFormat,
    );
  }

  Response response({
    String status = 'completed',
    List<Map<String, dynamic>> output = const [],
    Map<String, dynamic>? usage,
    Map<String, dynamic>? error,
  }) {
    return Response.fromJson({
      'id': 'resp_1',
      'object': 'response',
      'created_at': 1,
      'status': status,
      'output': output,
      if (usage != null) 'usage': usage,
      if (error != null) 'error': error,
    });
  }

  List<Item> itemsOf(CreateResponseRequest request) =>
      (request.input as ResponseInputItems).items;

  Map<String, dynamic> usageJson() => {
    'input_tokens': 10,
    'output_tokens': 4,
    'total_tokens': 14,
    'input_tokens_details': {'cached_tokens': 6},
    'output_tokens_details': {'reasoning_tokens': 2},
  };

  group('请求映射', () {
    test('system 消息进 instructions，不进 input', () {
      final request = toResponseRequest(
        chatRequest(
          messages: [
            ChatMessage.system('你是 Athena'),
            ChatMessage.user('你好'),
          ],
        ),
      );

      expect(request.instructions, '你是 Athena');
      final items = itemsOf(request);
      expect(items, hasLength(1));
      final json = items.single.toJson();
      expect(json['type'], 'message');
      expect(json['role'], 'user');
      expect((json['content'] as List).single, containsPair('text', '你好'));
    });

    test('多条 system 消息合并，user 消息保留顺序', () {
      final request = toResponseRequest(
        chatRequest(
          messages: [
            ChatMessage.system('第一段'),
            ChatMessage.user('问题'),
            ChatMessage.system('第二段'),
          ],
        ),
      );

      expect(request.instructions, '第一段\n\n第二段');
      expect(itemsOf(request), hasLength(1));
    });

    test('assistant 的 tool_calls 变成 function_call item', () {
      final request = toResponseRequest(
        chatRequest(
          messages: [
            ChatMessage.user('列出文件'),
            AssistantMessage(
              content: '好的',
              toolCalls: [
                ToolCall(
                  id: 'call_1',
                  type: 'function',
                  function: FunctionCall(
                    name: 'bash',
                    arguments: '{"command":"ls"}',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final items = itemsOf(request);
      expect(items, hasLength(3));

      final assistantJson = items[1].toJson();
      expect(assistantJson['type'], 'message');
      expect(assistantJson['role'], 'assistant');

      final callJson = items[2].toJson();
      expect(callJson['type'], 'function_call');
      expect(callJson['call_id'], 'call_1');
      expect(callJson['name'], 'bash');
      expect(callJson['arguments'], '{"command":"ls"}');
    });

    test('tool 结果变成 function_call_output item', () {
      final request = toResponseRequest(
        chatRequest(
          messages: [
            ToolMessage(toolCallId: 'call_1', content: 'file_a\nfile_b'),
          ],
        ),
      );

      final json = itemsOf(request).single.toJson();
      expect(json['type'], 'function_call_output');
      expect(json['call_id'], 'call_1');
      expect(json['output'], 'file_a\nfile_b');
    });

    test('工具定义转成 Responses 的扁平 function 工具', () {
      final request = toResponseRequest(
        chatRequest(
          tools: [
            Tool.function(
              name: 'file_read',
              description: '读文件',
              parameters: {
                'type': 'object',
                'properties': {
                  'path': {'type': 'string'},
                },
                'required': ['path'],
              },
            ),
          ],
        ),
      );

      final tool = request.tools!.single as FunctionTool;
      expect(tool.name, 'file_read');
      expect(tool.description, '读文件');
      expect(tool.parameters!['type'], 'object');
    });

    test('temperature 与推理强度透传', () {
      final request = toResponseRequest(
        chatRequest(temperature: 0.3, reasoningEffort: ReasoningEffort.high),
      );

      expect(request.temperature, 0.3);
      expect(request.reasoning!.effort, ReasoningEffort.high);
    });

    test('jsonObject 输出格式映射到 text.format', () {
      final request = toResponseRequest(
        chatRequest(responseFormat: JsonObjectResponseFormat()),
      );

      expect(request.text!.format, isA<JsonObjectFormat>());
    });

    test('图片内容映射成 input_image', () {
      final request = toResponseRequest(
        chatRequest(
          messages: [
            UserMessage(
              content: UserPartsContent([
                const TextContentPart(text: '看这张图'),
                const ImageContentPart(url: 'data:image/png;base64,AAAA'),
              ]),
            ),
          ],
        ),
      );

      final content = itemsOf(request).single.toJson()['content'] as List;
      expect(content[0], containsPair('type', 'input_text'));
      expect(content[1], containsPair('type', 'input_image'));
      expect(content[1], containsPair('image_url', 'data:image/png;base64,AAAA'));
    });

    test('表达不了的内容显式失败，而不是静默丢弃', () {
      expect(
        () => toResponseRequest(
          chatRequest(
            messages: [
              UserMessage(
                content: UserPartsContent([
                  const FileContentPart(fileId: 'file_1'),
                ]),
              ),
            ],
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(
        () => toResponseRequest(
          chatRequest(
            responseFormat: JsonSchemaResponseFormat(
              name: 'out',
              schema: const {'type': 'object'},
            ),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('事件归一', () {
    List<ResponseStreamEvent> toolCallEvents() => [
      ResponseStreamEvent.fromJson({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'id': 'fc_1',
          'call_id': 'call_1',
          'name': 'bash',
          'arguments': '',
        },
      }),
      ResponseStreamEvent.fromJson({
        'type': 'response.function_call_arguments.delta',
        'item_id': 'fc_1',
        'output_index': 0,
        'delta': '{"command":',
      }),
      ResponseStreamEvent.fromJson({
        'type': 'response.function_call_arguments.delta',
        'item_id': 'fc_1',
        'output_index': 0,
        'delta': '"ls"}',
      }),
    ];

    test('文本与推理增量按 content / reasoning 呈现', () async {
      final chunks = await normalizeResponsesStream(
        Stream.fromIterable([
          ResponseStreamEvent.fromJson({
            'type': 'response.output_text.delta',
            'output_index': 0,
            'content_index': 0,
            'delta': '你好',
          }),
          ResponseStreamEvent.fromJson({
            'type': 'response.reasoning_text.delta',
            'output_index': 1,
            'content_index': 0,
            'delta': '思考中',
          }),
        ]),
      ).toList();

      expect(chunks[0].choices!.single.delta.content, '你好');
      expect(chunks[1].choices!.single.delta.reasoning, '思考中');
    });

    test('工具调用：先给 id 与 name 建卡，再追加参数分片', () async {
      final chunks = await normalizeResponsesStream(
        Stream.fromIterable(toolCallEvents()),
      ).toList();

      final built = chunks[0].choices!.single.delta.toolCalls!.single;
      expect(built.index, 0);
      expect(built.id, 'call_1');
      expect(built.function!.name, 'bash');

      expect(
        chunks[1].choices!.single.delta.toolCalls!.single.function!.arguments,
        '{"command":',
      );
      expect(
        chunks[2].choices!.single.delta.toolCalls!.single.function!.arguments,
        '"ls"}',
      );
    });

    test('多个工具调用：参数增量按 output_index 归位，reasoning 占位不留空洞',
        () async {
      Map<String, dynamic> added(int outputIndex, String n) => {
            'type': 'response.output_item.added',
            'output_index': outputIndex,
            'item': {
              'type': 'function_call',
              'id': 'fc_$n',
              'call_id': 'call_$n',
              'name': 'tool_$n',
              'arguments': '',
            },
          };
      Map<String, dynamic> delta(int outputIndex, String n, String d) => {
            'type': 'response.function_call_arguments.delta',
            'item_id': 'fc_$n',
            'output_index': outputIndex,
            'delta': d,
          };

      final accumulator = ChatStreamAccumulator();
      await for (final chunk in normalizeResponsesStream(
        Stream.fromIterable([
          // output_index 0 被 reasoning item 占据
          {
            'type': 'response.output_item.added',
            'output_index': 0,
            'item': {'type': 'reasoning', 'id': 'rs_1', 'summary': <Object>[]},
          },
          added(1, 'a'),
          added(2, 'b'),
          delta(2, 'b', '{"y":'),
          delta(1, 'a', '{"x":'),
          delta(1, 'a', '1}'),
          delta(2, 'b', '2}'),
        ].map(ResponseStreamEvent.fromJson)),
      )) {
        accumulator.add(chunk);
      }

      final calls = accumulator.toolCalls;
      expect(calls.map((c) => c.id), ['call_a', 'call_b']);
      expect(calls.map((c) => c.function.arguments), ['{"x":1}', '{"y":2}'],
          reason: '参数分片必须按 output_index 归到各自的调用上');
    });

    test('归一流可被 ChatStreamAccumulator 直接消费（上层零改动）', () async {
      final accumulator = ChatStreamAccumulator();
      await for (final chunk in normalizeResponsesStream(
        Stream.fromIterable([
          ResponseStreamEvent.fromJson({
            'type': 'response.output_text.delta',
            'output_index': 0,
            'content_index': 0,
            'delta': '好的',
          }),
          ...toolCallEvents(),
          ResponseStreamEvent.fromJson({
            'type': 'response.completed',
            'response': {
              'id': 'resp_1',
              'object': 'response',
              'created_at': 1,
              'status': 'completed',
              'output': <Map<String, dynamic>>[],
              'usage': usageJson(),
            },
          }),
        ]),
      )) {
        accumulator.add(chunk);
      }

      expect(accumulator.content, '好的');
      final calls = accumulator.toolCalls;
      expect(calls, hasLength(1));
      expect(calls.single.id, 'call_1');
      expect(calls.single.function.name, 'bash');
      expect(calls.single.function.arguments, '{"command":"ls"}');
      expect(accumulator.finishReason, FinishReason.stop);
      expect(accumulator.usage!.promptTokens, 10);
    });

    test('usage 的缓存与推理明细映射到 Chat Completions 字段', () async {
      final chunk = await normalizeResponsesStream(
        Stream.value(
          ResponseStreamEvent.fromJson({
            'type': 'response.completed',
            'response': {
              'id': 'resp_1',
              'object': 'response',
              'created_at': 1,
              'status': 'completed',
              'output': <Map<String, dynamic>>[],
              'usage': usageJson(),
            },
          }),
        ),
      ).single;

      expect(chunk.choices!.single.finishReason, FinishReason.stop);
      final usage = chunk.usage!;
      expect(usage.promptTokens, 10);
      expect(usage.completionTokens, 4);
      expect(usage.totalTokens, 14);
      expect(usage.promptTokensDetails!.cachedTokens, 6);
      expect(usage.completionTokensDetails!.reasoningTokens, 2);
    });

    test('incomplete 归一成 length，供上层拒绝截断的工具调用', () async {
      final chunk = await normalizeResponsesStream(
        Stream.value(
          ResponseStreamEvent.fromJson({
            'type': 'response.incomplete',
            'response': {
              'id': 'resp_1',
              'object': 'response',
              'created_at': 1,
              'status': 'incomplete',
              'output': <Map<String, dynamic>>[],
              'incomplete_details': {'reason': 'max_output_tokens'},
            },
          }),
        ),
      ).single;

      expect(chunk.choices!.single.finishReason, FinishReason.length);
    });

    test('failed 带出服务端错误信息', () async {
      await expectLater(
        normalizeResponsesStream(
          Stream.value(
            ResponseStreamEvent.fromJson({
              'type': 'response.failed',
              'response': {
                'id': 'resp_1',
                'object': 'response',
                'created_at': 1,
                'status': 'failed',
                'output': <Map<String, dynamic>>[],
                'error': {'type': 'server_error', 'message': 'boom'},
              },
            }),
          ),
        ),
        emitsError(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('boom'),
          ),
        ),
      );
    });
  });

  group('非流式路径', () {
    test('toChatCompletion 提取文本、用量与 finishReason', () {
      final completion = responseToChatCompletion(
        response(
          output: [
            {
              'type': 'message',
              'id': 'msg_1',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': '最终答案'},
              ],
            },
          ],
          usage: usageJson(),
        ),
      );

      expect(completion.text, '最终答案');
      expect(completion.choices.single.finishReason, FinishReason.stop);
      expect(completion.usage!.totalTokens, 14);
      expect(completion.usage!.promptTokensDetails!.cachedTokens, 6);
    });

    test('incomplete 状态的响应对应 length', () {
      final completion = responseToChatCompletion(response(status: 'incomplete'));

      expect(completion.choices.single.finishReason, FinishReason.length);
      expect(completion.text, '');
    });
  });
}
