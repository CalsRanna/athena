import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/util/retry.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';

/// A real [OpenAIClient] whose [close] is observable. The underlying network
/// calls are driven by an injected [http.Client] (a [MockClient]), so no
/// network access occurs. We override [close] only to record the call count;
/// `super.close()` remains idempotent.
class _ObservableClient extends OpenAIClient {
  int closeCount = 0;

  _ObservableClient(http.Client httpClient)
      : super(
          config: const OpenAIConfig(baseUrl: 'https://example.test/v1'),
          httpClient: httpClient,
          // abort 路径使用独立的专用 client；注入同一 mock 使测试
          // 不依赖真实网络。
          streamClientFactory: () => httpClient,
        );

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

/// A client pointing at an unroutable local port: connection fails
/// immediately (no DNS), used to exercise the abort path deterministically.
class _AbortClient extends OpenAIClient {
  int closeCount = 0;
  _AbortClient()
      : super(
          config: const OpenAIConfig(
            baseUrl: 'http://127.0.0.1:9/v1', // discard 端口，通常无监听
          ),
        );

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

ProviderEntity _provider() => ProviderEntity(
      name: 'test',
      baseUrl: 'https://example.test/v1',
      apiKey: 'sk-test',
      createdAt: DateTime(2024),
    );

/// Minimal valid non-streaming chat completion JSON body.
String _completionBody(String content) => jsonEncode({
      'id': 'chatcmpl-test',
      'object': 'chat.completion',
      'created': 0,
      'model': 'gpt-test',
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        }
      ],
    });

/// Builds a single SSE `data:` frame for a streaming chunk delivering [content].
String _sseChunk(String content) {
  final json = jsonEncode({
    'id': 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': 0,
    'model': 'gpt-test',
    'choices': [
      {
        'index': 0,
        'delta': {'role': 'assistant', 'content': content},
        'finish_reason': null,
      }
    ],
  });
  return 'data: $json\n\n';
}

ChatCompletionCreateRequest _streamRequest() => ChatCompletionCreateRequest(
      model: 'gpt-test',
      messages: [ChatMessage.user('hi')],
    );

ChatCompletionCreateRequest _fetchRequest() => ChatCompletionCreateRequest(
      model: 'gpt-test',
      messages: [ChatMessage.user('hi')],
    );

void main() {
  // Use a fast retry config so failure-path tests don't wait on backoff.
  final fastRetry = const RetryConfig(
    maxAttempts: 1,
    baseDelay: Duration.zero,
    maxDelay: Duration.zero,
  );

  test('fetch() closes the client exactly once on success', () async {
    late _ObservableClient observed;
    final mock = MockClient((request) async {
      return http.Response(_completionBody('done'), 200,
          headers: {'content-type': 'application/json'});
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _ObservableClient(mock);
        return observed;
      },
    );

    final response = await llmClient.fetch(
      provider: _provider(),
      request: _fetchRequest(),
    );

    expect(response.text, 'done');
    expect(observed.closeCount, 1);
  });

  test('fetch() closes the client when the operation throws', () async {
    late _ObservableClient observed;
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'boom', 'type': 'server_error'}
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _ObservableClient(mock);
        return observed;
      },
    );

    await expectLater(
      llmClient.fetch(provider: _provider(), request: _fetchRequest()),
      throwsA(isA<Object>()),
    );

    // finally must still close despite the thrown error.
    expect(observed.closeCount, 1);
  });

  test('stream() closes the client after normal drain', () async {
    late _ObservableClient observed;
    final mock = MockClient.streaming((request, bodyStream) async {
      final body = '${_sseChunk('hello')}data: [DONE]\n\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _ObservableClient(mock);
        return observed;
      },
    );

    final events = await llmClient
        .stream(provider: _provider(), request: _streamRequest())
        .toList();

    expect(events, isNotEmpty);
    expect(observed.closeCount, 1);
  });

  test('stream() closes the client when subscription is cancelled mid-stream',
      () async {
    late _ObservableClient observed;
    // A controller we keep open so the stream never completes on its own; the
    // consumer cancels mid-stream after the first chunk.
    final bodyController = StreamController<List<int>>();
    final mock = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        bodyController.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _ObservableClient(mock);
        return observed;
      },
    );

    final firstChunk = Completer<void>();
    late StreamSubscription sub;
    sub = llmClient
        .stream(provider: _provider(), request: _streamRequest())
        .listen((event) {
      if (!firstChunk.isCompleted) firstChunk.complete();
    });

    // Push one chunk so the consumer enters the stream, then cancel.
    bodyController.add(utf8.encode(_sseChunk('partial')));
    await firstChunk.future;
    await sub.cancel();

    // Cancellation runs the async* `finally`, which closes the client.
    expect(observed.closeCount, 1);

    await bodyController.close();
  });

  test('stream() idle timeout aborts a stalled stream (no infinite hang)',
      () async {
    late _ObservableClient observed;
    // 流保持打开但不产出任何数据（网络静默场景）。
    final bodyController = StreamController<List<int>>();
    final mock = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        bodyController.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _ObservableClient(mock);
        return observed;
      },
      streamIdleTimeout: const Duration(milliseconds: 100),
    );

    await expectLater(
      llmClient.stream(provider: _provider(), request: _streamRequest()).toList(),
      throwsA(isA<TimeoutException>()),
    );
    expect(observed.closeCount, 1);
    await bodyController.close();
  });

  test('stream() cancelSignal aborts the underlying request', () async {
    // abort 路径使用 openai_dart 的专用 client（不经注入的 mock），
    // 因此这里用真实 client 连 127.0.0.1 未监听端口：连接立即失败、
    // 无 DNS 参与，行为确定且快。
    late _AbortClient observed;
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) {
        observed = _AbortClient();
        return observed;
      },
    );

    final token = CancelToken();
    final terminated = Completer<void>();
    llmClient
        .stream(
          provider: ProviderEntity(
            name: 't',
            baseUrl: 'http://127.0.0.1:9/v1',
            apiKey: 'k',
            createdAt: DateTime(2024),
          ),
          request: _streamRequest(),
          cancelSignal: token.whenCancelled,
        )
        .listen(
      (_) {},
      onError: (Object e) {
        if (!terminated.isCompleted) terminated.complete();
      },
      onDone: () {
        if (!terminated.isCompleted) terminated.complete();
      },
    );
    await Future.delayed(const Duration(milliseconds: 50));
    token.cancel();
    // abort 触发后底层请求被取消，流应终止（不永久挂起）。
    await terminated.future.timeout(const Duration(seconds: 2), onTimeout: () {
      fail('stream did not terminate after cancelSignal fired');
    });
    // onError 先于 generator 的 finally 传播，轮询等待 client 被关闭。
    for (var i = 0; i < 50 && observed.closeCount == 0; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    expect(observed.closeCount, 1,
        reason: '取消后 LlmClient.stream 的 finally 应关闭 client');
  });

  // ---------- ChatService.reasoningEffort 传递 ----------

  ChatEntity chatWithEffort(String? effort) => ChatEntity(
        title: 'test chat',
        modelId: 1,
        sentinelId: 1,
        reasoningEffort: effort,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  ModelEntity model() => ModelEntity(
        name: 'test model',
        modelId: 'gpt-test',
        providerId: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  /// 捕获 ChatService.getCompletion 发出的请求体。
  Future<Map<String, dynamic>> captureRequest(ChatEntity chat) async {
    final captured = Completer<Map<String, dynamic>>();
    final mock = MockClient.streaming((request, bodyStream) async {
      final body = await utf8.decodeStream(bodyStream);
      captured.complete(jsonDecode(body) as Map<String, dynamic>);
      return http.StreamedResponse(
        Stream.value(utf8.encode('${_sseChunk('hi')}data: [DONE]\n\n')),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final llmClient = LlmClient(
      retryConfig: fastRetry,
      clientFactory: ({required apiKey, baseUrl}) => _ObservableClient(mock),
    );
    final service = ChatService(llmClient: llmClient);
    await service
        .getCompletion(
          chat: chat,
          messages: [ChatMessage.user('hi')],
          provider: _provider(),
          model: model(),
        )
        .toList();
    return captured.future;
  }

  test('getCompletion() passes reasoningEffort to the request', () async {
    final body = await captureRequest(chatWithEffort('high'));
    expect(body['reasoning_effort'], 'high');
  });

  test('getCompletion() passes max even though SDK enum lacks it', () async {
    final body = await captureRequest(chatWithEffort('max'));
    expect(body['reasoning_effort'], 'max');
  });

  test('getCompletion() omits reasoning_effort when chat effort is null',
      () async {
    final body = await captureRequest(chatWithEffort(null));
    expect(body.containsKey('reasoning_effort'), isFalse);
  });

  test('getCompletion() omits reasoning_effort for unrecognized values',
      () async {
    final body = await captureRequest(chatWithEffort('super-duper'));
    expect(body.containsKey('reasoning_effort'), isFalse);
  });
}
