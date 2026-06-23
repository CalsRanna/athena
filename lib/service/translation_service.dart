import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

/// TranslationService 负责翻译相关的网络请求
class TranslationService {
  final LlmClient _llmClient;

  TranslationService({required LlmClient llmClient}) : _llmClient = llmClient;

  Stream<ChatDelta> translate({
    required List<ChatMessage> messages,
    required ModelEntity model,
    required ProviderEntity provider,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
    );
    var stream = _llmClient.stream(provider: provider, request: request);
    await for (final chunk in stream) {
      if (chunk.choices == null || chunk.choices!.isEmpty) continue;
      yield chunk.choices!.first.delta;
    }
  }
}
