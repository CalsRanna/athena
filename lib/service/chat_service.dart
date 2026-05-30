import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/util/retry.dart';
import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';

/// 创建与 AI 提供商通信的 [OpenAIClient] 的工厂签名。
///
/// 默认实现返回真实的 [OpenAIClient.withApiKey]。仅在测试中被替换，
/// 以便观察 [OpenAIClient.close] 是否被正确调用（见 C1 修复）。
typedef OpenAIClientFactory = OpenAIClient Function({
  required String apiKey,
  required String? baseUrl,
});

/// ChatService 负责与 AI 提供商进行聊天相关的网络请求
class ChatService {
  RetryConfig retryConfig = const RetryConfig();

  /// 用于创建 [OpenAIClient] 的工厂，默认指向真实实现。
  ///
  /// 通过可选构造参数注入，便于测试断言客户端在使用完毕后被关闭。
  final OpenAIClientFactory _clientFactory;

  ChatService({@visibleForTesting OpenAIClientFactory? clientFactory})
      : _clientFactory = clientFactory ?? _defaultClientFactory;

  static OpenAIClient _defaultClientFactory({
    required String apiKey,
    required String? baseUrl,
  }) {
    return OpenAIClient.withApiKey(
      apiKey,
      baseUrl: baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
  }

  /// 测试连接
  Future<String> connect({
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var client = _clientFactory(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
    );
    try {
      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: [ChatMessage.user('Hi')],
      );
      var response = await retry(
        () => client.chat.completions.create(request),
        config: retryConfig,
      );
      return response.text ?? '';
    } finally {
      client.close();
    }
  }

  /// 获取聊天完成流
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    var client = _clientFactory(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
    );
    try {
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
    } finally {
      client.close();
    }
  }

  /// 非流式完成，用于辅助模型摘要等场景
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var client = _clientFactory(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
    );
    try {
      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: messages,
      );
      var response = await retry(
        () => client.chat.completions.create(request),
        config: retryConfig,
      );
      return response.text ?? '';
    } finally {
      client.close();
    }
  }

  /// 获取聊天标题流
  Stream<String> getTitle(
    String value, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var client = _clientFactory(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
    );
    try {
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
    } finally {
      client.close();
    }
  }
}
