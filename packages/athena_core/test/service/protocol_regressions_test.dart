import 'dart:convert';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/messages_adapter.dart';
import 'package:athena_core/service/responses_adapter.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/responses_fixture.dart';

ChatStreamEvent chunk(Map<String, dynamic> delta, [String? stop]) =>
    ChatStreamEvent.fromJson({
      'choices': [
        {'index': 0, 'delta': delta, if (stop != null) 'finish_reason': stop},
      ],
    });

void main() {
  final provider = responsesProvider().copyWith(
    apiFormat: ApiFormat.chatCompletions,
  );
  final now = DateTime(2026);

  for (final format in [ApiFormat.chatCompletions, ApiFormat.responses]) {
    test('${format.value} 实际 HTTP 请求按模型保留或省略会话温度', () async {
      final bodies = <Map<String, dynamic>>[];
      final service = ChatCompletionsService(
        llmClient: LlmClient(
          retryConfig: const RetryConfig(maxAttempts: 1),
          clientFactory: ({required apiKey, required baseUrl}) {
            final mock = MockClient((request) async {
              bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
              return http.Response(
                format == ApiFormat.responses
                    ? responsesSse([
                        {
                          'type': 'response.completed',
                          'response': reasoningResponse(tools: false),
                        },
                      ])
                    : 'data: ${jsonEncode(chunk({'content': 'ok'}, 'stop').toJson())}\n\n',
                200,
                headers: {'content-type': 'text/event-stream; charset=utf-8'},
              );
            });
            return OpenAIClient.withApiKey(
              apiKey,
              baseUrl: baseUrl,
              httpClient: mock,
              streamClientFactory: () => mock,
            );
          },
        ),
      );
      for (final (id, effort, reasoning, expected) in [
        ('gpt-5.4', 'high', true, null),
        ('openai/gpt-5.4', 'high', true, null),
        ('gpt-5-mini', 'low', true, null),
        ('gpt-5', 'none', true, null),
        ('o3-mini', 'high', true, null),
        ('gpt-5.4', 'none', true, 0.6),
        ('deepseek-reasoner', 'high', true, 0.6),
        ('gpt-4.1', 'high', false, 0.6),
      ]) {
        await service
            .getCompletion(
              chat: ChatEntity(
                title: 'test',
                modelId: '1',
                sentinelId: '0',
                temperature: 0.6,
                reasoningEffort: effort,
                createdAt: now,
                updatedAt: now,
              ),
              provider: provider.copyWith(apiFormat: format),
              model: ModelEntity(
                name: id,
                modelId: id,
                providerId: '1',
                reasoning: reasoning,
                createdAt: now,
                updatedAt: now,
              ),
              messages: [ChatMessage.user('hi')],
            )
            .toList();
        expect(bodies.last['temperature'], expected, reason: '$id / $effort');
        expect(bodies.last.containsKey('temperature'), expected != null);
      }
    });
  }

  test('Messages 非对象和损坏的历史参数不阻断 tool_result 续接', () {
    for (final args in [
      '[]',
      'null',
      '"text"',
      '1',
      'true',
      '{"broken',
      '{"ok":1}',
    ]) {
      final request = toMessageRequest(
        ChatCompletionCreateRequest(
          model: 'claude-sonnet-4-6',
          messages: [
            ChatMessage.user('hi'),
            ChatMessage.assistant(
              toolCalls: [
                ToolCall(
                  id: 'call_1',
                  type: 'function',
                  function: FunctionCall(name: 'echo', arguments: args),
                ),
              ],
            ),
            ChatMessage.tool(
              toolCallId: 'call_1',
              content: 'Invalid arguments, please retry',
            ),
          ],
        ),
      ).toJson();
      final messages = request['messages'] as List;
      expect(
        messages[1]['content'][0]['input'],
        args == '{"ok":1}' ? {'ok': 1} : <String, dynamic>{},
        reason: args,
      );
      expect(messages[2]['content'][0]['tool_use_id'], 'call_1');
      expect(
        messages[2]['content'][0]['content'][0]['text'],
        contains('Invalid arguments'),
      );
    }
  });

  final details = [
    {'type': 'reasoning.summary', 'summary': '先读', 'index': 0},
    {'type': 'reasoning.summary', 'summary': '配置。', 'index': 0},
    {'type': 'reasoning.encrypted', 'data': 'secret', 'index': 1},
    {
      'type': 'reasoning.text',
      'text': '再验证。',
      'signature': 'signature',
      'index': 2,
    },
  ];
  test('Chat details 增量展示可读内容，原生回传仍保留完整签名与密文', () async {
    final chunks = await normalizeChatCompletionsStream(
      Stream.fromIterable([
        for (final d in details)
          chunk({
            'reasoning_details': [d],
          }),
        chunk({'content': 'ok'}, 'stop'),
      ]),
      provider,
      'test',
    ).toList();
    final acc = ChatStreamAccumulator();
    chunks.forEach(acc.add);
    expect(acc.reasoningContent, '先读配置。\n\n再验证。');
    final state = chunks.whereType<ChatCompletionsStateChunk>().single.state;
    expect(state.message.toJson()['reasoning_details'], details);
    expect(state.message.reasoningContent, isNull);
    final response = normalizeChatCompletion(
      ChatCompletion.fromJson({
        'object': 'chat.completion',
        'model': 'test',
        'choices': [
          {
            'index': 0,
            'finish_reason': 'stop',
            'message': {
              'role': 'assistant',
              'content': 'ok',
              'reasoning_content': '',
              'reasoning_details': details,
            },
          },
        ],
      }),
      provider,
      'test',
    );
    expect(
      response.choices.single.message.reasoningContent,
      acc.reasoningContent,
    );
  });

  for (final order in ['same', 'details_first', 'legacy_first']) {
    test('Chat 两个推理通道 $order 不重复展示', () async {
      final delta = {
        'reasoning_details': [details.first],
      };
      final legacy = {'reasoning': '先读'};
      final chunks = await normalizeChatCompletionsStream(
        Stream.fromIterable([
          if (order == 'same')
            chunk({...delta, ...legacy})
          else ...[
            chunk(order == 'details_first' ? delta : legacy),
            chunk(order == 'details_first' ? legacy : delta),
          ],
          chunk({'content': 'ok'}, 'stop'),
        ]),
        provider,
        'test',
      ).toList();
      final acc = ChatStreamAccumulator();
      chunks.forEach(acc.add);
      expect(acc.reasoningContent, '先读');
      expect(
        chunks
            .whereType<ChatCompletionsStateChunk>()
            .single
            .state
            .message
            .reasoning,
        '先读',
      );
    });
  }

  for (final mode in [
    'delta_done',
    'done',
    'item_done',
    'completed',
    'added',
  ]) {
    test('Responses $mode 补齐正文与多工具参数且不重复', () async {
      final response = reasoningResponse();
      final output = response['output'] as List;
      final events = <Map<String, dynamic>>[];
      if (mode == 'delta_done') {
        events.add({
          'type': 'response.output_text.delta',
          'output_index': 1,
          'content_index': 0,
          'delta': '准备',
        });
      }
      if (mode != 'completed') {
        for (var i = 2; i < output.length; i++) {
          events.add({
            'type': 'response.output_item.added',
            'output_index': i,
            'item': {
              ...output[i] as Map<String, dynamic>,
              if (mode != 'added') 'arguments': '',
            },
          });
          if (mode == 'delta_done') {
            events.add({
              'type': 'response.function_call_arguments.delta',
              'output_index': i,
              'delta': (output[i]['arguments'] as String).substring(0, 10),
            });
          }
        }
      }
      if (mode == 'done' || mode == 'delta_done') {
        events.add({
          'type': 'response.output_text.done',
          'output_index': 1,
          'content_index': 0,
          'text': '准备执行。',
        });
        for (var i = 2; i < output.length; i++) {
          events.add({
            'type': 'response.function_call_arguments.done',
            'output_index': i,
            'arguments': output[i]['arguments'],
          });
        }
      }
      if (mode != 'completed') {
        for (var i = 1; i < output.length; i++) {
          events.add({
            'type': 'response.output_item.done',
            'output_index': i,
            'item': output[i],
          });
        }
      }
      events.add({'type': 'response.completed', 'response': response});
      final chunks = await normalizeResponsesStream(
        Stream.fromIterable(events.map(ResponseStreamEvent.fromJson)),
        provider: responsesProvider(),
        model: 'test-reasoner',
      ).toList();
      final acc = ChatStreamAccumulator();
      chunks.forEach(acc.add);
      expect(acc.content, '准备执行。');
      expect(acc.toolCalls.map((c) => c.id), ['call_1_0', 'call_1_1']);
      expect(
        acc.toolCalls.map((c) => c.function.arguments),
        output.skip(2).map((i) => i['arguments']),
      );
      expect(
        chunks.whereType<ResponsesStateChunk>().single.state.matchesMessage(
          AssistantMessage(content: acc.content, toolCalls: acc.toolCalls),
        ),
        isTrue,
      );
    });
  }

  test('Responses 参数 done 早于调用元数据时先缓存、终态建卡时完整发送', () async {
    final response = reasoningResponse();
    final output = response['output'] as List;
    final events = [
      for (var i = 2; i < output.length; i++)
        {
          'type': 'response.function_call_arguments.done',
          'output_index': i,
          'arguments': output[i]['arguments'],
        },
      {'type': 'response.completed', 'response': response},
    ];
    final acc = ChatStreamAccumulator();
    await for (final c in normalizeResponsesStream(
      Stream.fromIterable(events.map(ResponseStreamEvent.fromJson)),
    )) {
      acc.add(c);
    }
    expect(
      acc.toolCalls.map((c) => c.function.arguments),
      output.skip(2).map((i) => i['arguments']),
    );
  });

  for (final type in ['text', 'arguments']) {
    test('Responses $type 终态与已发增量不一致时失败', () async {
      final response = reasoningResponse();
      final events = <Map<String, dynamic>>[
        if (type == 'text')
          {
            'type': 'response.output_text.delta',
            'output_index': 1,
            'content_index': 0,
            'delta': 'different',
          }
        else
          {
            'type': 'response.function_call_arguments.delta',
            'output_index': 2,
            'delta': '{"different":1}',
          },
        {'type': 'response.completed', 'response': response},
      ];
      await expectLater(
        normalizeResponsesStream(
          Stream.fromIterable(events.map(ResponseStreamEvent.fromJson)),
        ).toList(),
        throwsA(isA<FormatException>()),
      );
    });
  }
}
