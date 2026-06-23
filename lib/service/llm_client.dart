import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/util/retry.dart';
import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';

/// 创建 [OpenAIClient] 的工厂签名。可通过构造参数注入，便于测试。
typedef OpenAIClientFactory = OpenAIClient Function({
  required String apiKey,
  required String? baseUrl,
});

/// 统一的 LLM API 客户端。
///
/// 职责：封装 [OpenAIClient] 生命周期（创建、请求、关闭）、
/// 重试策略、Athena 标准 Headers。所有 LLM API 调用都应通过此类。
class LlmClient {
  final OpenAIClientFactory _clientFactory;
  RetryConfig _retryConfig;

  LlmClient({
    RetryConfig retryConfig = const RetryConfig(),
    @visibleForTesting OpenAIClientFactory? clientFactory,
  })  : _retryConfig = retryConfig,
        _clientFactory = clientFactory ?? _defaultClientFactory;

  void updateRetryConfig(RetryConfig config) {
    _retryConfig = config;
  }

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

  OpenAIClient _createClient(String apiKey, String? baseUrl) {
    return _clientFactory(apiKey: apiKey, baseUrl: baseUrl);
  }

  /// 流式完成请求。自动创建 client → 重试 → close。
  Stream<ChatStreamEvent> stream({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
  }) async* {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      yield* retryStream(
        () => client.chat.completions.createStream(request),
        config: _retryConfig,
      );
    } finally {
      client.close();
    }
  }

  /// 非流式完成请求。自动创建 client → 重试 → close。
  Future<ChatCompletion> fetch({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
  }) async {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      return await retry(
        () => client.chat.completions.create(request),
        config: _retryConfig,
      );
    } finally {
      client.close();
    }
  }
}
