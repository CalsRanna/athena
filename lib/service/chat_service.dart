import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/util/retry.dart';
import 'package:openai_dart/openai_dart.dart';

/// ChatService 负责与 AI 提供商进行聊天相关的网络请求
class ChatService {
  RetryConfig retryConfig = const RetryConfig();

  /// 测试连接
  Future<String> connect({
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [ChatMessage.user('Hi')],
    );
    var response = await retry(
      () => client.chat.completions.create(request),
      config: retryConfig,
    );
    return response.text ?? '';
  }

  /// 获取聊天完成流
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: chat.temperature,
      tools: tools,
    );
    yield* retryStream(
      () => client.chat.completions.createStream(request),
      config: retryConfig,
    );
  }

  /// 获取聊天标题流
  Stream<String> getTitle(
    String value, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [
        ChatMessage.system(PresetPrompt.namingPrompt),
        ChatMessage.user(value),
      ],
    );
    var response = retryStream(
      () => client.chat.completions.createStream(request),
      config: retryConfig,
    );
    await for (final chunk in response) {
      if (chunk.choices == null || chunk.choices!.isEmpty) continue;
      yield chunk.choices!.first.delta.content ?? '';
    }
  }
}
