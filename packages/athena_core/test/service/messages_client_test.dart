import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// Messages 协议走真实的 anthropic_sdk_dart 客户端，HTTP 层换成 [MockClient]：
/// 断言的是实际发出去的请求体与重试次数。
void main() {
  final provider = ProviderEntity(
    name: 'anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    apiKey: 'k',
    apiFormat: ApiFormat.messages,
    createdAt: DateTime(2026),
  );

  late List<Map<String, dynamic>> bodies;

  LlmClient client(List<http.Response> responses) {
    var index = 0;
    final mock = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return responses[index < responses.length
          ? index++
          : responses.length - 1];
    });
    return LlmClient(
      retryConfig: const RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 5),
      ),
      anthropicClientFactory: ({required apiKey, required baseUrl}) =>
          anthropic.AnthropicClient(
            config: anthropic.AnthropicConfig(
              authProvider: anthropic.ApiKeyProvider(apiKey),
              baseUrl: baseUrl,
              retryPolicy: const anthropic.RetryPolicy(maxRetries: 0),
            ),
            httpClient: mock,
          ),
    );
  }

  setUp(() => bodies = []);

  http.Response error(int status, String type) => http.Response(
    jsonEncode({
      'type': 'error',
      'error': {'type': type, 'message': 'x'},
    }),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response sse(List<Map<String, dynamic>> events) => http.Response(
    events.map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n').join(),
    200,
    headers: {'content-type': 'text/event-stream'},
  );

  final okStream = sse([
    {
      'type': 'message_start',
      'message': {
        'id': 'msg_1',
        'type': 'message',
        'role': 'assistant',
        'model': 'claude',
        'content': <Object>[],
        'stop_reason': null,
        'usage': {'input_tokens': 1, 'output_tokens': 0},
      },
    },
    {
      'type': 'content_block_start',
      'index': 0,
      'content_block': {'type': 'text', 'text': ''},
    },
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': 'ok'},
    },
    {'type': 'content_block_stop', 'index': 0},
    {
      'type': 'message_delta',
      'delta': {'stop_reason': 'end_turn'},
      'usage': {'output_tokens': 1},
    },
    {'type': 'message_stop'},
  ]);

  ChatCompletionCreateRequest request({double? temperature}) =>
      ChatCompletionCreateRequest(
        model: 'claude',
        messages: [ChatMessage.user('hi')],
        temperature: temperature,
      );

  group('max_tokens', () {
    Future<int> sentMaxTokens({int outputLimit = 0, int? outputRoom}) async {
      await client([okStream])
          .stream(
            provider: provider,
            request: request(),
            outputLimit: outputLimit,
            outputRoom: outputRoom,
          )
          .drain<void>();
      return bodies.last['max_tokens'] as int;
    }

    test('模型输出上限已知时用它，而不是固定 8192', () async {
      expect(await sentMaxTokens(outputLimit: 64000), 64000);
    });

    test('窗口余量更小时按余量收紧，输入 + 输出不超出窗口', () async {
      expect(await sentMaxTokens(outputLimit: 64000, outputRoom: 5000), 5000);
    });

    test('上限未知时退回 8192', () async {
      expect(await sentMaxTokens(), 8192);
    });
  });

  // 此前 responseFormat 非 null 会在 toMessageRequest 里抛 UnsupportedError，
  // 请求根本发不出去：README 记录的 `/json` 模式对 Anthropic 用户必然失败。
  test('/json 请求真的发得出去，并把 JSON 约束放进 system', () async {
    await client([okStream])
        .stream(
          provider: provider,
          request: ChatCompletionCreateRequest(
            model: 'claude',
            messages: [ChatMessage.user('hi')],
            responseFormat: ResponseFormat.jsonObject(),
          ),
        )
        .drain<void>();

    expect(bodies, hasLength(1), reason: '请求必须真的发出去');
    expect(jsonEncode(bodies.single['system']), contains('JSON'));
    expect(
      bodies.single.containsKey('response_format'),
      isFalse,
      reason: 'Messages 没有这个字段，不能硬塞',
    );
  });

  test('温度按 Messages 的 0–1 范围收紧', () async {
    await client([okStream])
        .stream(provider: provider, request: request(temperature: 1.6))
        .drain<void>();
    expect(bodies.single['temperature'], 1.0);
  });

  group('重试', () {
    test('过载（529）与 5xx 会重试', () async {
      final events = await client([
        error(529, 'overloaded_error'),
        error(500, 'api_error'),
        okStream,
      ]).stream(provider: provider, request: request()).toList();

      expect(bodies, hasLength(3));
      expect(
        events.map((e) => e.choices?.firstOrNull?.delta.content ?? '').join(),
        'ok',
      );
    });

    test('流内的 overloaded_error 事件同样重试', () async {
      await client([
        sse([
          {
            'type': 'error',
            'error': {'type': 'overloaded_error', 'message': 'busy'},
          },
        ]),
        okStream,
      ]).stream(provider: provider, request: request()).drain<void>();

      expect(bodies, hasLength(2));
    });

    test('请求本身有问题（400）不重试', () async {
      await expectLater(
        client([
          error(400, 'invalid_request_error'),
        ]).stream(provider: provider, request: request()),
        emitsError(isA<anthropic.ApiException>()),
      );
      expect(bodies, hasLength(1));
    });
  });

  test('非法字符的 tool_use id 在 tool_use 与 tool_result 两侧一致地改写', () async {
    await client([okStream])
        .stream(
          provider: provider,
          request: ChatCompletionCreateRequest(
            model: 'claude',
            messages: [
              ChatMessage.user('run'),
              ChatMessage.assistant(
                toolCalls: [
                  ToolCall(
                    id: 'functions.bash:0',
                    type: 'function',
                    function: const FunctionCall(name: 'bash', arguments: '{}'),
                  ),
                ],
              ),
              ChatMessage.tool(toolCallId: 'functions.bash:0', content: 'done'),
            ],
          ),
        )
        .drain<void>();

    final messages = (bodies.single['messages'] as List).cast<Map>();
    final toolUse = (messages[1]['content'] as List).cast<Map>().single;
    final toolResult = (messages[2]['content'] as List).cast<Map>().single;
    expect(toolUse['id'], matches(RegExp(r'^[a-zA-Z0-9_-]+$')));
    expect(toolResult['tool_use_id'], toolUse['id']);
  });
}
