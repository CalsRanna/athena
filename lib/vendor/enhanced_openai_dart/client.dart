import 'dart:async';
import 'dart:convert';

import 'package:athena/vendor/enhanced_openai_dart/response.dart';
import 'package:openai_dart/openai_dart.dart';
// ignore: implementation_imports
import 'package:openai_dart/src/generated/client.dart' as g;

class EnhancedOpenAIClient extends OpenAIClient {
  EnhancedOpenAIClient({
    super.apiKey,
    super.organization,
    super.beta,
    super.baseUrl,
    super.headers,
    super.queryParams,
    super.client,
  });

  Stream<EnhancedCreateChatCompletionStreamResponse>
  createOverrodeChatCompletionStream({
    required final CreateChatCompletionRequest request,
  }) async* {
    final streamResponse = await makeRequestStream(
      baseUrl: 'https://api.openai.com/v1',
      path: '/chat/completions',
      method: g.HttpMethod.post,
      requestType: 'application/json',
      responseType: 'application/json',
      body: request.copyWith(stream: true),
    );
    yield* streamResponse.stream
        .transform(const _OpenAIStreamTransformer())
        .map((final string) {
          try {
            var rawJson = json.decode(string);
            var response = CreateChatCompletionStreamResponse.fromJson(rawJson);
            return EnhancedCreateChatCompletionStreamResponse(
              rawJson: rawJson,
              response: response,
            );
          } catch (e) {
            var baseUrl = this.baseUrl ?? 'https://api.openai.com/v1';
            var uri = Uri.parse('$baseUrl/chat/completions');
            throw OpenAIClientException(
              message: string,
              method: g.HttpMethod.post,
              uri: uri,
            );
          }
        });
  }
}

class _OpenAIStreamTransformer
    extends StreamTransformerBase<List<int>, String> {
  const _OpenAIStreamTransformer();

  @override
  Stream<String> bind(final Stream<List<int>> stream) {
    return stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where(
          (final line) => line.startsWith('data: ') && !line.endsWith('[DONE]'),
        )
        .map((final item) => item.substring(6));
  }
}
