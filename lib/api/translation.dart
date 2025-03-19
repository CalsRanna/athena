import 'dart:async';

import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;

class TranslationApi {
  Stream<ChatCompletionStreamResponseDelta> translate({
    required List<ChatCompletionMessage> messages,
    required Model model,
    required Provider provider,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: messages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta;
    }
  }
}
