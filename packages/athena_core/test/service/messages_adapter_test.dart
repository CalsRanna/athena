import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/service/messages_adapter.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 覆盖 Messages 适配器的两侧映射，重点是与另两条协议的三处实质差异：
/// system 上提与角色合并、工具参数在对象/JSON 字符串之间互转、
/// 用量分散在 message_start 与 message_delta 两个事件里。
void main() {
  ChatCompletionCreateRequest chatRequest({
    List<ChatMessage>? messages,
    List<Tool>? tools,
    double? temperature,
    ResponseFormat? responseFormat,
  }) => ChatCompletionCreateRequest(
    model: 'claude-sonnet-5',
    messages: messages ?? [ChatMessage.user('hi')],
    tools: tools,
    temperature: temperature,
    responseFormat: responseFormat,
  );

  anthropic.MessageStreamEvent event(Map<String, dynamic> json) =>
      anthropic.MessageStreamEvent.fromJson(json);

  Map<String, dynamic> messageStart({int inputTokens = 10, int? cacheRead}) => {
    'type': 'message_start',
    'message': {
      'id': 'msg_1',
      'type': 'message',
      'role': 'assistant',
      'model': 'claude-sonnet-5',
      'content': <Map<String, dynamic>>[],
      'usage': {
        'input_tokens': inputTokens,
        'output_tokens': 1,
        if (cacheRead != null) 'cache_read_input_tokens': cacheRead,
      },
    },
  };

  List<Map<String, dynamic>> blocksOf(anthropic.InputMessage message) =>
      (message.toJson()['content'] as List).cast<Map<String, dynamic>>();

  group('请求映射', () {
    test('system 消息上提为顶层 system，不进 messages', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            ChatMessage.system('你是 Athena'),
            ChatMessage.user('你好'),
          ],
        ),
      );

      expect(request.system, isNotNull);
      expect(request.system!.toJson(), contains('你是 Athena'));
      expect(request.messages, hasLength(1));
      expect(request.messages.single.toJson()['role'], 'user');
    });

    test('max_tokens 有默认值（Messages 里必填，Chat Completions 里 Athena 从不传）', () {
      expect(toMessageRequest(chatRequest()).maxTokens, greaterThan(0));
    });

    test('连续同角色的消息合并成一条（Messages 要求 user / assistant 交替）', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            ChatMessage.user('第一句'),
            ChatMessage.user('第二句'),
            ChatMessage.system('中途提醒'),
            AssistantMessage(content: '回答'),
            AssistantMessage(content: '补充'),
          ],
        ),
      );

      expect(request.messages, hasLength(2));
      expect(request.messages[0].toJson()['role'], 'user');
      expect(blocksOf(request.messages[0]), hasLength(2));
      expect(request.messages[1].toJson()['role'], 'assistant');
      expect(blocksOf(request.messages[1]), hasLength(2));
      // 中途的 system 一样上提到顶层，不留在 messages 里打断角色交替
      expect(request.system!.toJson(), contains('中途提醒'));
    });

    test('assistant 的 tool_calls 转成 tool_use，参数从 JSON 字符串变对象', () {
      final request = toMessageRequest(
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

      final blocks = blocksOf(request.messages[1]);
      expect(blocks[0], containsPair('type', 'text'));
      expect(blocks[1], containsPair('type', 'tool_use'));
      expect(blocks[1]['id'], 'call_1');
      expect(blocks[1]['name'], 'bash');
      expect(blocks[1]['input'], {'command': 'ls'});
    });

    test('参数不是合法 JSON 时下发空对象，而不是打挂整轮', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            AssistantMessage(
              content: null,
              toolCalls: [
                ToolCall(
                  id: 'call_1',
                  type: 'function',
                  function: FunctionCall(name: 'bash', arguments: '{"comm'),
                ),
              ],
            ),
          ],
        ),
      );

      expect(blocksOf(request.messages.single)[0]['input'], isEmpty);
    });

    test('tool 结果变成 user 消息里的 tool_result block', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [ToolMessage(toolCallId: 'call_1', content: 'file_a')],
        ),
      );

      final block = blocksOf(request.messages.single).single;
      expect(request.messages.single.toJson()['role'], 'user');
      expect(block['type'], 'tool_result');
      expect(block['tool_use_id'], 'call_1');
    });

    test('工具定义的 JSON Schema 拆成 input_schema，其余关键字不丢', () {
      final tool = toMessageRequest(
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
                'additionalProperties': false,
              },
            ),
          ],
        ),
      ).tools!.single.toJson();

      expect(tool['name'], 'file_read');
      expect(tool['description'], '读文件');
      final schema = tool['input_schema'] as Map;
      expect(schema['type'], 'object');
      expect(schema['properties'], {
        'path': {'type': 'string'},
      });
      expect(schema['required'], ['path']);
      expect(schema['additionalProperties'], false);
    });

    test('data URL 图片拆成 base64 source，媒体类型一并带出', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            UserMessage(
              content: UserPartsContent([
                const ImageContentPart(url: 'data:image/png;base64,AAAA'),
              ]),
            ),
          ],
        ),
      );

      final block = blocksOf(request.messages.single).single;
      expect(block['type'], 'image');
      final source = block['source'] as Map;
      expect(source['type'], 'base64');
      expect(source['media_type'], 'image/png');
      expect(source['data'], 'AAAA');
    });

    test('空 text part 被丢弃，仅图片消息只剩 image block', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            UserMessage(
              content: UserPartsContent([
                const TextContentPart(text: ''),
                const ImageContentPart(url: 'data:image/png;base64,AAAA'),
              ]),
            ),
          ],
        ),
      );

      final blocks = blocksOf(request.messages.single);
      expect(blocks.map((b) => b['type']), ['image'],
          reason: 'Messages 协议拒绝空 text block');
    });

    test('http(s) 图片用 url source', () {
      final request = toMessageRequest(
        chatRequest(
          messages: [
            UserMessage(
              content: UserPartsContent([
                const ImageContentPart(url: 'https://example.com/a.png'),
              ]),
            ),
          ],
        ),
      );

      final source =
          blocksOf(request.messages.single).single['source'] as Map;
      expect(source['type'], 'url');
      expect(source['url'], 'https://example.com/a.png');
    });

    test('表达不了的内容显式失败', () {
      expect(
        () => toMessageRequest(
          chatRequest(
            messages: [
              UserMessage(
                content: UserPartsContent([
                  const ImageContentPart(url: 'data:image/svg+xml,%3Csvg/%3E'),
                ]),
              ),
            ],
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // /json 模式在 Messages 下没有对应参数，必须报错而不是静默失效
      expect(
        () => toMessageRequest(
          chatRequest(responseFormat: const JsonObjectResponseFormat()),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('事件归一', () {
    List<Map<String, dynamic>> toolCallEvents() => [
      {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'tool_use',
          'id': 'toolu_1',
          'name': 'bash',
          'input': <String, dynamic>{},
        },
      },
      {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"command":'},
      },
      {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '"ls"}'},
      },
    ];

    test('文本与推理增量分别进 content / reasoning', () async {
      final chunks = await normalizeMessagesStream(
        Stream.fromIterable([
          event({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': '你好'},
          }),
          event({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'thinking_delta', 'thinking': '思考中'},
          }),
        ]),
      ).toList();

      expect(chunks[0].choices!.single.delta.content, '你好');
      expect(chunks[1].choices!.single.delta.reasoning, '思考中');
    });

    test('工具调用：content block 下标重编号后再呈现', () async {
      final chunks = await normalizeMessagesStream(
        Stream.fromIterable(toolCallEvents().map(event)),
      ).toList();

      final built = chunks[0].choices!.single.delta.toolCalls!.single;
      // 文本块占了 content block 0，工具块在 1；归一到 toolCalls 的下标 0
      expect(built.index, 0);
      expect(built.id, 'toolu_1');
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

    test('归一流可被 ChatStreamAccumulator 直接消费（上层零改动）', () async {
      final accumulator = ChatStreamAccumulator();
      await for (final chunk in normalizeMessagesStream(
        Stream.fromIterable([
          event(messageStart(cacheRead: 4)),
          event({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': '好的'},
          }),
          ...toolCallEvents().map(event),
          event({
            'type': 'message_delta',
            'delta': {'stop_reason': 'tool_use'},
            'usage': {'output_tokens': 7},
          }),
        ]),
      )) {
        accumulator.add(chunk);
      }

      expect(accumulator.content, '好的');
      final calls = accumulator.toolCalls;
      expect(calls, hasLength(1));
      expect(calls.single.id, 'toolu_1');
      expect(calls.single.function.name, 'bash');
      expect(calls.single.function.arguments, '{"command":"ls"}');
      expect(accumulator.finishReason, FinishReason.toolCalls);
      // input 用量来自 message_start，output 来自 message_delta
      expect(accumulator.usage!.promptTokens, 10);
      expect(accumulator.usage!.completionTokens, 7);
      expect(accumulator.usage!.promptTokensDetails!.cachedTokens, 4);
    });

    test('stop_reason 映射：max_tokens 归一成 length', () async {
      final chunk = await normalizeMessagesStream(
        Stream.fromIterable([
          event(messageStart()),
          event({
            'type': 'message_delta',
            'delta': {'stop_reason': 'max_tokens'},
            'usage': {'output_tokens': 3},
          }),
        ]),
      ).last;

      expect(chunk.choices!.single.finishReason, FinishReason.length);
    });

    test('end_turn 映射成 stop', () async {
      final chunk = await normalizeMessagesStream(
        Stream.fromIterable([
          event(messageStart()),
          event({
            'type': 'message_delta',
            'delta': {'stop_reason': 'end_turn'},
            'usage': {'output_tokens': 3},
          }),
        ]),
      ).last;

      expect(chunk.choices!.single.finishReason, FinishReason.stop);
      expect(chunk.id, 'msg_1');
    });

    test('error 事件带出服务端信息', () async {
      await expectLater(
        normalizeMessagesStream(
          Stream.value(
            event({
              'type': 'error',
              'error': {'type': 'overloaded_error', 'message': 'boom'},
            }),
          ),
        ),
        emitsError(
          isA<StateError>().having((e) => e.message, 'message', contains('boom')),
        ),
      );
    });
  });

  group('非流式路径', () {
    test('messageToChatCompletion 拼接文本并带出用量与 stopReason', () {
      final completion = messageToChatCompletion(
        anthropic.Message.fromJson({
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'model': 'claude-sonnet-5',
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': '第一段'},
            {'type': 'text', 'text': '第二段'},
          ],
          'usage': {
            'input_tokens': 10,
            'output_tokens': 4,
            'cache_read_input_tokens': 6,
          },
        }),
      );

      expect(completion.text, '第一段第二段');
      expect(completion.choices.single.finishReason, FinishReason.stop);
      expect(completion.usage!.promptTokens, 10);
      expect(completion.usage!.completionTokens, 4);
      expect(completion.usage!.totalTokens, 14);
      expect(completion.usage!.promptTokensDetails!.cachedTokens, 6);
    });

    test('tool_use 结束时对应 tool_calls', () {
      final completion = messageToChatCompletion(
        anthropic.Message.fromJson({
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'model': 'claude-sonnet-5',
          'stop_reason': 'tool_use',
          'content': [
            {
              'type': 'tool_use',
              'id': 'toolu_1',
              'name': 'bash',
              'input': {'command': 'ls'},
            },
          ],
          'usage': {'input_tokens': 1, 'output_tokens': 2},
        }),
      );

      expect(completion.choices.single.finishReason, FinishReason.toolCalls);
      expect(completion.text, '');
    });
  });
}
