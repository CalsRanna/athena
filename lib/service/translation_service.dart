import 'dart:async';

import 'package:athena/entity/ai_provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:openai_dart/openai_dart.dart';

/// TranslationService 负责翻译相关的网络请求
class TranslationService {
  Stream<ChatCompletionStreamResponseDelta> translate({
    required List<ChatCompletionMessage> messages,
    required ModelEntity model,
    required AIProviderEntity provider,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: messages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta;
    }
  }
}
