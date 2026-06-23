import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/service/llm_client.dart';
import 'package:athena/util/retry.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
