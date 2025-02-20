import 'dart:async';
import 'dart:convert';

import 'package:athena/vendor/openai_dart/response.dart';
import 'package:openai_dart/openai_dart.dart';
// ignore: implementation_imports
import 'package:openai_dart/src/generated/client.dart' as g;

class OverrodeOpenAIClient extends OpenAIClient {
  OverrodeOpenAIClient({
    super.apiKey,
    super.organization,
    super.beta,
    super.baseUrl,
    super.headers,
    super.queryParams,
    super.client,
  });

  Stream<OverrodeCreateChatCompletionStreamResponse>
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
      var rawJson = json.decode(string);
      var response = CreateChatCompletionStreamResponse.fromJson(rawJson);
      return OverrodeCreateChatCompletionStreamResponse(
        rawJson: rawJson,
        response: response,
      );
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
        .where((final line) =>
            line.startsWith('data: ') && !line.endsWith('[DONE]'))
        .map((final item) => item.substring(6));
  }
}
