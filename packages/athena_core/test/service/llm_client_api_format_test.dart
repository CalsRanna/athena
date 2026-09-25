import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 覆盖 `LlmClient` 的协议分派：未接入的格式必须显式失败且以流错误呈现，
/// Chat Completions 必须仍然走到原有的 openai_dart 调用路径。
void main() {
  ProviderEntity provider(ApiFormat format) => ProviderEntity(
    name: 'probe',
    baseUrl: 'https://example.com',
    apiKey: 'test-key',
    apiFormat: format,
    createdAt: DateTime(2026, 1, 1),
  );

  ChatCompletionCreateRequest request() => ChatCompletionCreateRequest(
    model: 'test-model',
    messages: [ChatMessage.user('hi')],
  );

  group('未接入的协议', () {
    for (final format in [ApiFormat.messages]) {
      test('${format.value}：stream 以流错误呈现 UnsupportedError', () async {
        final client = LlmClient();

        // 同步调用本身不能抛：上层把 await for 包在 try 里做取消归一化，
        // 同步抛出会绕过那段逻辑。
        late final Stream<ChatStreamEvent> stream;
        expect(
          () => stream = client.stream(
            provider: provider(format),
            request: request(),
          ),
          returnsNormally,
        );

        await expectLater(stream, emitsError(isA<UnsupportedError>()));
      });

      test('${format.value}：fetch 抛出 UnsupportedError', () async {
        final client = LlmClient();
        await expectLater(
          client.fetch(provider: provider(format), request: request()),
          throwsA(isA<UnsupportedError>()),
        );
      });
    }

    test('错误信息包含 provider 名与格式，指出恢复方式', () async {
      final client = LlmClient();
      final error = await client
          .fetch(provider: provider(ApiFormat.messages), request: request())
          .then<Object?>((_) => null, onError: (Object e) => e);

      final message = (error! as UnsupportedError).message;
      expect(message, contains('probe'));
      expect(message, contains('messages'));
      expect(message, contains('chat_completions'));
    });
  });

  group('Responses', () {
    test('stream 进入 Responses 分支，不报 UnsupportedError', () async {
      final client = LlmClient(
        clientFactory: ({required apiKey, required baseUrl}) =>
            throw StateError('responses-reached'),
      );

      await expectLater(
        client.stream(
          provider: provider(ApiFormat.responses),
          request: request(),
        ),
        emitsError(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'responses-reached',
          ),
        ),
      );
    });

    test('fetch 进入 Responses 分支，不报 UnsupportedError', () async {
      final client = LlmClient(
        clientFactory: ({required apiKey, required baseUrl}) =>
            throw StateError('responses-reached'),
      );

      await expectLater(
        client.fetch(
          provider: provider(ApiFormat.responses),
          request: request(),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'responses-reached',
          ),
        ),
      );
    });
  });

  group('Chat Completions', () {
    test('stream 进入 Chat Completions 分支，不报 UnsupportedError', () async {
      // 用抛自定义异常的工厂证明「确实走到了 openai_dart 分支」：
      // 若被误判为未接入协议，错误类型会是 UnsupportedError。
      final client = LlmClient(
        clientFactory: ({required apiKey, required baseUrl}) =>
            throw StateError('chat-completions-reached'),
      );

      await expectLater(
        client.stream(
          provider: provider(ApiFormat.chatCompletions),
          request: request(),
        ),
        emitsError(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'chat-completions-reached',
          ),
        ),
      );
    });

    test('fetch 进入 Chat Completions 分支，不报 UnsupportedError', () async {
      final client = LlmClient(
        clientFactory: ({required apiKey, required baseUrl}) =>
            throw StateError('chat-completions-reached'),
      );

      await expectLater(
        client.fetch(
          provider: provider(ApiFormat.chatCompletions),
          request: request(),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'chat-completions-reached',
          ),
        ),
      );
    });
  });
}
