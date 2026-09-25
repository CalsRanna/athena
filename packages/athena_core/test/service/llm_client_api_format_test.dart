import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// `LlmClient` 按 `provider.apiFormat` 分派三条协议路径：Chat Completions 与
/// Responses 都用 openai_dart 客户端（Responses 走 `client.responses`），
/// Messages 用 anthropic_sdk_dart 客户端。
///
/// 这里用「注入的工厂直接抛错」证明进了哪条分支，避免真的发请求；
/// 顺带钉住 Messages 的地址归一化（SDK 自己会拼 `/v1/messages`）。
void main() {
  ProviderEntity provider(
    ApiFormat format, {
    String baseUrl = 'https://example.com',
  }) => ProviderEntity(
    name: 'probe',
    baseUrl: baseUrl,
    apiKey: 'test-key',
    apiFormat: format,
    createdAt: DateTime(2026, 1, 1),
  );

  ChatCompletionCreateRequest request() => ChatCompletionCreateRequest(
    model: 'test-model',
    messages: [ChatMessage.user('hi')],
  );

  LlmClient openAiClient() => LlmClient(
    clientFactory: ({required String apiKey, required String? baseUrl}) =>
        throw StateError('openai-client-created'),
  );

  LlmClient anthropicClient({void Function(String baseUrl)? onBaseUrl}) =>
      LlmClient(
        anthropicClientFactory:
            ({required String apiKey, required String baseUrl}) {
              onBaseUrl?.call(baseUrl);
              throw StateError('anthropic-client-created');
            },
      );

  Matcher marker(String message) =>
      isA<StateError>().having((e) => e.message, 'message', message);

  group('协议分派', () {
    for (final format in [ApiFormat.chatCompletions, ApiFormat.responses]) {
      test('${format.value}：走 openai_dart 客户端', () async {
        final client = openAiClient();

        await expectLater(
          client.stream(provider: provider(format), request: request()),
          emitsError(marker('openai-client-created')),
        );
        await expectLater(
          client.fetch(provider: provider(format), request: request()),
          throwsA(marker('openai-client-created')),
        );
      });
    }

    test('messages：走 anthropic_sdk_dart 客户端', () async {
      final client = anthropicClient();

      await expectLater(
        client.stream(
          provider: provider(ApiFormat.messages),
          request: request(),
        ),
        emitsError(marker('anthropic-client-created')),
      );
      await expectLater(
        client.fetch(
          provider: provider(ApiFormat.messages),
          request: request(),
        ),
        throwsA(marker('anthropic-client-created')),
      );
    });

    test('messages：地址尾部的 /v1 被剥掉', () async {
      String? seen;
      final client = anthropicClient(onBaseUrl: (url) => seen = url);

      await expectLater(
        client.fetch(
          provider: provider(
            ApiFormat.messages,
            baseUrl: 'https://api.anthropic.com/v1',
          ),
          request: request(),
        ),
        throwsA(isA<StateError>()),
      );

      expect(seen, 'https://api.anthropic.com');
    });

    test('messages：不带 /v1 的地址（含尾斜杠）原样传递', () async {
      String? seen;
      final client = anthropicClient(onBaseUrl: (url) => seen = url);

      await expectLater(
        client.fetch(
          provider: provider(
            ApiFormat.messages,
            baseUrl: 'https://proxy.example.com/anthropic/',
          ),
          request: request(),
        ),
        throwsA(isA<StateError>()),
      );

      expect(seen, 'https://proxy.example.com/anthropic');
    });
  });
}
