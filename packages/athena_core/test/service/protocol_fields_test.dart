import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/completion_details.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/messages_adapter.dart';
import 'package:athena_core/service/responses_adapter.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/responses_fixture.dart';

ChatCompletionCreateRequest request([Map<String, dynamic> fields = const {}]) =>
    ChatCompletionCreateRequest.fromJson({
      'model': 'test-model',
      'messages': [
        {'role': 'user', 'content': 'hi'},
      ],
      ...fields,
    });

Map<String, dynamic> messageJson({String stop = 'end_turn'}) => {
  'id': 'msg_test',
  'type': 'message',
  'role': 'assistant',
  'model': 'test-model',
  'content': [
    {'type': 'text', 'text': 'answer'},
  ],
  'stop_reason': stop,
  'usage': {
    'input_tokens': 10,
    'output_tokens': 5,
    'cache_read_input_tokens': 100,
    'cache_creation_input_tokens': 20,
    'cache_creation': {
      'ephemeral_5m_input_tokens': 8,
      'ephemeral_1h_input_tokens': 12,
    },
  },
};

void main() {
  final tools = [
    {
      'type': 'function',
      'function': {
        'name': 'echo',
        'strict': true,
        'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
      },
    },
  ];

  test('Responses 实际请求携带显式控制参数与 strict', () {
    final body = toResponseRequest(
      request({
        'max_completion_tokens': 1234,
        'top_p': 0.4,
        'tools': tools,
        'tool_choice': {
          'type': 'function',
          'function': {'name': 'echo'},
        },
        'parallel_tool_calls': false,
        'metadata': {'audit': 'yes'},
        'service_tier': 'auto',
        'prompt_cache_key': 'cache',
        'safety_identifier': 'user',
        'verbosity': 'low',
        'store': true,
      }),
    ).toJson();
    expect(body['max_output_tokens'], 1234);
    expect(body['top_p'], 0.4);
    expect(body['tool_choice'], {'type': 'function', 'name': 'echo'});
    expect(body['parallel_tool_calls'], false);
    expect((body['tools'] as List).single['strict'], true);
    expect(body['metadata'], {'audit': 'yes'});
    expect(body['service_tier'], 'auto');
    expect(body['prompt_cache_key'], 'cache');
    expect(body['safety_identifier'], 'user');
    expect(body['text'], {'verbosity': 'low'});
    expect(body['store'], true);
  });

  test('Messages 显式上限、采样、停止序列和工具控制映射；预算只收紧', () {
    final req = request({
      'max_completion_tokens': 1234,
      'top_p': 0.4,
      'top_k': 12,
      'tools': tools,
      'tool_choice': 'required',
      'parallel_tool_calls': false,
      'stop': ['END'],
      'user': 'user-test',
    });
    final body = toMessageRequest(req, maxTokens: 4096).toJson();
    expect(body['max_tokens'], 1234);
    expect(body['top_p'], 0.4);
    expect(body['top_k'], 12);
    expect(body['stop_sequences'], ['END']);
    expect(body['metadata'], {'user_id': 'user-test'});
    expect(body['tool_choice'], {
      'type': 'any',
      'disable_parallel_tool_use': true,
    });
    expect((body['tools'] as List).single['strict'], true);
    expect(toMessageRequest(req, maxTokens: 1000).maxTokens, 1000);
  });

  for (final choice in ['auto', 'none', 'required']) {
    test('两条适配器映射 tool_choice=$choice', () {
      final req = request({'tools': tools, 'tool_choice': choice});
      expect(toResponseRequest(req).toJson()['tool_choice'], choice);
      expect(toMessageRequest(req).toJson()['tool_choice'], {
        'type': choice == 'required' ? 'any' : choice,
      });
    });
  }

  test('未提供 tool_choice 时仍映射并行开关；指定工具保留名称', () {
    expect(
      toMessageRequest(
        request({'parallel_tool_calls': false}),
      ).toJson()['tool_choice'],
      {'type': 'auto', 'disable_parallel_tool_use': true},
    );
    expect(
      toMessageRequest(
        request({
          'tool_choice': {
            'type': 'function',
            'function': {'name': 'echo'},
          },
        }),
      ).toJson()['tool_choice'],
      {'type': 'tool', 'name': 'echo'},
    );
  });

  test('不能等价表达的显式参数必须失败，冲突上限不能静默择一', () {
    for (final convert in [toResponseRequest, toMessageRequest]) {
      for (final fields in [
        {'seed': 42},
        {'n': 2},
        {
          'logit_bias': {'1': 1},
        },
      ]) {
        expect(() => convert(request(fields)), throwsUnsupportedError);
      }
      expect(
        () => convert(request({'max_tokens': 20, 'max_completion_tokens': 30})),
        throwsArgumentError,
      );
    }
    expect(
      () => toMessageRequest(
        request({
          'metadata': {'key': 'value'},
        }),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => toResponseRequest(request({'prompt_cache_retention': '24h'})),
      throwsUnsupportedError,
    );
  });

  test('Messages 缓存读写纳入总输入，同时保留缓存写入明细', () {
    final result = messageToChatCompletion(
      anthropic.Message.fromJson(messageJson()),
    );
    expect(result.usage!.promptTokens, 130);
    expect(result.usage!.totalTokens, 135);
    expect(result.usage!.promptTokensDetails!.cachedTokens, 100);
    expect((result.usage as CacheUsage).cacheCreationTokens, 20);
    expect(
      (result as DetailedChatCompletion).details['usage']['cache_creation'],
      {'ephemeral_5m_input_tokens': 8, 'ephemeral_1h_input_tokens': 12},
    );
  });

  test('Messages 流式累计更新用量，不丢 message_start 的缓存写入', () async {
    final events = [
      {'type': 'message_start', 'message': messageJson()},
      {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn'},
        'usage': {'output_tokens': 6},
      },
      {'type': 'message_stop'},
    ];
    final chunks = await normalizeMessagesStream(
      Stream.fromIterable(events.map(anthropic.MessageStreamEvent.fromJson)),
    ).toList();
    final acc = ChatStreamAccumulator();
    chunks.forEach(acc.add);
    expect(acc.usage!.promptTokens, 130);
    expect(acc.usage!.totalTokens, 136);
    expect((acc.usage as CacheUsage).cacheCreationTokens, 20);
    expect(
      chunks
          .whereType<CompletionDetailsChunk>()
          .single
          .details['usage']['cache_creation_input_tokens'],
      20,
    );
  });

  for (final entry in {
    'end_turn': FinishReason.stop,
    'stop_sequence': FinishReason.stop,
    'tool_use': FinishReason.toolCalls,
    'max_tokens': FinishReason.length,
    'model_context_window_exceeded': FinishReason.length,
    'refusal': FinishReason.contentFilter,
  }.entries) {
    test('Messages ${entry.key} 映射并保留原始原因', () {
      final result =
          messageToChatCompletion(
                anthropic.Message.fromJson(messageJson(stop: entry.key)),
              )
              as DetailedChatCompletion;
      expect(result.choices.single.finishReason, entry.value);
      expect(result.details['stop_reason'], entry.key);
    });
  }

  test('Messages pause_turn/compaction 明确不支持，拒答说明不为空', () {
    for (final stop in ['pause_turn', 'compaction']) {
      expect(
        () => messageToChatCompletion(
          anthropic.Message.fromJson(messageJson(stop: stop)),
        ),
        throwsUnsupportedError,
      );
    }
    final result = messageToChatCompletion(
      anthropic.Message.fromJson({
        ...messageJson(stop: 'refusal'),
        'content': <dynamic>[],
        'stop_details': {'type': 'refusal', 'explanation': 'Cannot answer'},
      }),
    );
    expect(result.text, 'Cannot answer');
    expect(result.choices.single.message.refusal, 'Cannot answer');
  });

  test('Responses 拒答 delta/done/终态去重；fetch 同样可显示', () async {
    final response = {
      ...reasoningResponse(tools: false),
      'output': [
        {
          'type': 'message',
          'id': 'msg',
          'role': 'assistant',
          'status': 'completed',
          'content': [
            {'type': 'refusal', 'refusal': 'Cannot answer'},
          ],
        },
      ],
    };
    final chunks = await normalizeResponsesStream(
      Stream.fromIterable([
        const RefusalDeltaEvent(
          outputIndex: 0,
          contentIndex: 0,
          delta: 'Cannot ',
        ),
        const RefusalDoneEvent(
          outputIndex: 0,
          contentIndex: 0,
          refusal: 'Cannot answer',
        ),
        ResponseCompletedEvent(response: Response.fromJson(response)),
      ]),
    ).toList();
    final acc = ChatStreamAccumulator();
    chunks.forEach(acc.add);
    expect(acc.content, 'Cannot answer');
    expect(acc.refusal, 'Cannot answer');
    expect(
      chunks.whereType<CompletionDetailsChunk>().single.details['refusal'],
      'Cannot answer',
    );
    final complete = responseToChatCompletion(Response.fromJson(response));
    expect(complete.text, 'Cannot answer');
    expect(complete.choices.single.message.refusal, 'Cannot answer');
  });

  test('非流式拒答再次发送时只出现一次，不把显示内容重复写进 wire message', () {
    final response = Response.fromJson({
      ...reasoningResponse(tools: false),
      'output': [
        {
          'type': 'message',
          'id': 'msg',
          'role': 'assistant',
          'status': 'completed',
          'content': [
            {'type': 'refusal', 'refusal': 'Cannot answer'},
          ],
        },
      ],
    });
    final assistant = responseToChatCompletion(response).choices.single.message;
    final next = request().copyWith(
      messages: [ChatMessage.user('hi'), assistant],
    );
    final input = toResponseRequest(next).toJson()['input'] as List;
    expect(input.last['content'], [
      {'type': 'refusal', 'refusal': 'Cannot answer'},
    ]);
    final messages = toMessageRequest(next).toJson()['messages'] as List;
    expect(messages.last['content'], [
      {'type': 'text', 'text': 'Cannot answer'},
    ]);
  });

  test('Messages 不把空 refusal 转成非法空文本块', () {
    final req = request().copyWith(
      messages: [
        ChatMessage.user('hi'),
        const AssistantMessage(content: 'answer', refusal: ''),
      ],
    );
    final messages = toMessageRequest(req).toJson()['messages'] as List;
    expect(messages.last['content'], [
      {'type': 'text', 'text': 'answer'},
    ]);
  });

  test('Responses HTTP 200 SSE error 进入重试，第二次流才产生正文', () async {
    var attempts = 0;
    final client = LlmClient(
      retryConfig: const RetryConfig(
        maxAttempts: 2,
        baseDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
      clientFactory: ({required apiKey, required baseUrl}) {
        final mock = MockClient((_) async {
          attempts++;
          final events = attempts == 1
              ? [
                  {'type': 'error', 'code': 'server_error', 'message': 'retry'},
                ]
              : reasoningEvents(reasoningResponse(tools: false));
          return http.Response(
            responsesSse(events),
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
    );
    final acc = ChatStreamAccumulator();
    await client
        .stream(provider: responsesProvider(), request: request())
        .forEach(acc.add);
    expect(acc.content, '完成。');
    expect(attempts, 2);
  });

  test('Responses error 与 EOF 报错；failed 不能伪装成功', () async {
    await expectLater(
      normalizeResponsesStream(
        Stream.value(
          const ErrorEvent(code: 'rate_limit_exceeded', message: 'wait'),
        ),
      ).toList(),
      throwsA(isA<RateLimitException>()),
    );
    await expectLater(
      normalizeResponsesStream(const Stream.empty()).toList(),
      throwsStateError,
    );
    expect(
      () => responseToChatCompletion(
        Response.fromJson({
          ...reasoningResponse(tools: false),
          'status': 'failed',
          'error': {'code': 'server_error', 'message': 'failed'},
        }),
      ),
      throwsA(isA<InternalServerException>()),
    );
    for (final status in ['queued', 'in_progress', 'cancelled']) {
      expect(
        () => responseToChatCompletion(
          Response.fromJson({
            ...reasoningResponse(tools: false),
            'status': status,
          }),
        ),
        throwsStateError,
      );
    }
  });

  test('Responses 区分工具结束、内容过滤与 token 截断', () {
    expect(
      responseToChatCompletion(
        Response.fromJson(reasoningResponse()),
      ).choices.single.finishReason,
      FinishReason.toolCalls,
    );
    final result =
        responseToChatCompletion(
              Response.fromJson({
                ...reasoningResponse(status: 'incomplete'),
                'incomplete_details': {'reason': 'content_filter'},
              }),
            )
            as DetailedChatCompletion;
    expect(result.choices.single.finishReason, FinishReason.contentFilter);
    expect(result.details['incomplete_details'], {'reason': 'content_filter'});
  });

  test('Responses HTTP 200 failed 在 retry 内检查，成功后才返回', () async {
    var attempts = 0;
    final client = LlmClient(
      retryConfig: const RetryConfig(
        maxAttempts: 2,
        baseDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
      clientFactory: ({required apiKey, required baseUrl}) =>
          OpenAIClient.withApiKey(
            apiKey,
            baseUrl: baseUrl,
            httpClient: MockClient((_) async {
              attempts++;
              return http.Response(
                jsonEncode(
                  attempts == 1
                      ? {
                          ...reasoningResponse(),
                          'status': 'failed',
                          'error': {'code': 'server_error', 'message': 'retry'},
                        }
                      : reasoningResponse(tools: false),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
    );
    expect(
      (await client.fetch(
        provider: responsesProvider(),
        request: request(),
      )).text,
      '完成。',
    );
    expect(attempts, 2);
  });

  test('Chat Completions 拒答可显示；流缺结束标记必须失败', () async {
    final provider = responsesProvider().copyWith(
      apiFormat: ApiFormat.chatCompletions,
    );
    final chunks = await normalizeChatCompletionsStream(
      Stream.fromIterable([
        ChatStreamEvent.fromJson({
          'choices': [
            {
              'index': 0,
              'delta': {'refusal': 'No'},
            },
          ],
        }),
        ChatStreamEvent.fromJson({
          'choices': [
            {'index': 0, 'delta': <String, dynamic>{}, 'finish_reason': 'stop'},
          ],
        }),
      ]),
      provider,
      'test-model',
    ).toList();
    final acc = ChatStreamAccumulator();
    chunks.forEach(acc.add);
    expect(acc.content, 'No');
    expect(
      chunks.whereType<CompletionDetailsChunk>().single.details['refusal'],
      'No',
    );
    await expectLater(
      normalizeChatCompletionsStream(
        const Stream.empty(),
        provider,
        'test-model',
      ).toList(),
      throwsStateError,
    );
  });

  test('Chat 推理原始字段经序列化和历史转换回传，切换来源和编辑后失效', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'athena_protocol_fields_',
    );
    addTearDown(() => tmp.delete(recursive: true));
    final storage = FileStorage(root: tmp);
    await storage.load();
    final provider = responsesProvider().copyWith(
      apiFormat: ApiFormat.chatCompletions,
    );
    final details = [
      {'type': 'reasoning.encrypted', 'data': 'opaque', 'id': 'r1', 'index': 0},
    ];
    final raw = ChatCompletion.fromJson({
      'object': 'chat.completion',
      'model': 'test-model',
      'choices': [
        {
          'index': 0,
          'finish_reason': 'stop',
          'message': {
            'role': 'assistant',
            'content': 'answer',
            'reasoning': 'think',
            'reasoning_details': details,
          },
        },
      ],
    });
    final normalized = normalizeChatCompletion(raw, provider, 'test-model');
    final state =
        (normalized.choices.single.message as ChatCompletionsAssistantMessage)
            .chatCompletionsState!;
    final record = MessageEntity.fromJson(
      MessageEntity(
        chatId: 1,
        role: 'assistant',
        content: 'answer',
        reasoningContent: 'think',
        chatCompletionsState: state.encode(),
      ).toJson(),
    );
    final converter = ChatMessageConverter(
      messageRepository: storage.sessionRepository,
    );
    final history = await converter.convertMessage(
      record,
      includeReasoning: true,
    );
    final req = request().copyWith(messages: history);
    final replayed = restoreChatCompletionsRequest(
      req,
      provider,
    ).toJson()['messages'][0];
    expect(replayed['reasoning'], 'think');
    expect(replayed['reasoning_details'], details);
    expect(jsonEncode(history.first.toJson()), isNot(contains('opaque')));
    expect(
      jsonEncode(
        restoreChatCompletionsRequest(
          req,
          provider.copyWith(baseUrl: 'https://other.test'),
        ).toJson(),
      ),
      isNot(contains('opaque')),
    );
    final edited = await converter.convertMessage(
      record.copyWith(content: 'edited'),
    );
    expect(
      jsonEncode(
        restoreChatCompletionsRequest(
          req.copyWith(messages: edited),
          provider,
        ).toJson(),
      ),
      isNot(contains('opaque')),
    );
  });
}
