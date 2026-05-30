import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:openai_dart/openai_dart.dart';

/// TranslationService 负责翻译相关的网络请求
class TranslationService {
  Stream<ChatDelta> translate({
    required List<ChatMessage> messages,
    required ModelEntity model,
    required ProviderEntity provider,
  }) async* {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    try {
      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: messages,
      );
      var response = client.chat.completions.createStream(request);
      await for (final chunk in response) {
        if (chunk.choices == null || chunk.choices!.isEmpty) continue;
        yield chunk.choices!.first.delta;
      }
    } finally {
      client.close();
    }
  }
}
