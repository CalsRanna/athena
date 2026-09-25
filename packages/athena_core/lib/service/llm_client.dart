import 'dart:async';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/messages_adapter.dart';
import 'package:athena_core/service/responses_adapter.dart';
import 'package:athena_core/util/retry.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

/// 给 [source] 加「事件间隙空闲超时」：两次事件间隔超过 [timeout] 时
/// 抛 [TimeoutException] 并终止流。
///
/// 注意：不能用 `Stream.timeout`——Dart 3.12 中它对「async* 生成器 +
/// `await for` 订阅流」的组合不触发（SDK 行为差异），这里用 Timer 手动
/// 实现，语义相同且与源流结构无关。
Stream<T> withIdleTimeout<T>(Stream<T> source, Duration timeout) {
  late StreamSubscription<T> sub;
  final controller = StreamController<T>();
  Timer? timer;

  void resetTimer() {
    timer?.cancel();
    timer = Timer(timeout, () {
      controller.addError(
        TimeoutException('Stream idle timeout after $timeout'),
      );
      unawaited(sub.cancel());
      unawaited(controller.close());
    });
  }

  controller.onListen = () {
    resetTimer();
    sub = source.listen(
      (event) {
        resetTimer();
        controller.add(event);
      },
      onError: (Object e, StackTrace st) {
        timer?.cancel();
        controller.addError(e, st);
      },
      onDone: () {
        timer?.cancel();
        unawaited(controller.close());
      },
    );
  };
  controller.onCancel = () {
    timer?.cancel();
    unawaited(sub.cancel());
  };
  return controller.stream;
}

/// 创建 [OpenAIClient] 的工厂签名。可通过构造参数注入，便于测试。
typedef OpenAIClientFactory = OpenAIClient Function({
  required String apiKey,
  required String? baseUrl,
});

/// 创建 [anthropic.AnthropicClient] 的工厂签名。可通过构造参数注入，便于测试。
typedef AnthropicClientFactory = anthropic.AnthropicClient Function({
  required String apiKey,
  required String baseUrl,
});

/// 统一的 LLM API 客户端。
///
/// 职责：按 `provider.apiFormat` 分派到具体协议实现，并封装底层 client 的
/// 生命周期（创建、请求、关闭）、重试策略、Athena 标准 Headers。
/// 所有 LLM API 调用都应通过此类。
///
/// 三条路径都已接入：Chat Completions 直接交给 openai_dart；Responses 与
/// Messages 分别经 `responses_adapter.dart` / `messages_adapter.dart` 做形状
/// 转换，对外仍是 Chat Completions 的请求与事件类型（上层不感知协议差异）。
class LlmClient {
  final OpenAIClientFactory _clientFactory;
  final AnthropicClientFactory _anthropicClientFactory;
  RetryConfig _retryConfig;
  final Duration _streamIdleTimeout;

  /// 流式 chunk 之间的空闲超时：连接保持但无数据到达（WiFi 断流、
  /// 代理挂起等）时终止流，避免 `await for` 永久挂起。
  static const streamIdleTimeout = Duration(minutes: 2);

  /// 非流式请求总超时：与流式空闲超时保持一致。无此超时时，
  /// 连接建立但服务端无响应（代理/中转挂起）会让请求永不返回，
  /// 造成上游 `isGenerating` 等状态永久卡死。
  static const fetchTimeout = Duration(minutes: 2);

  LlmClient({
    RetryConfig retryConfig = const RetryConfig(),
    @visibleForTesting OpenAIClientFactory? clientFactory,
    @visibleForTesting AnthropicClientFactory? anthropicClientFactory,
    Duration streamIdleTimeout = streamIdleTimeout,
  })  : _retryConfig = retryConfig,
        _clientFactory = clientFactory ?? _defaultClientFactory,
        _anthropicClientFactory =
            anthropicClientFactory ?? _defaultAnthropicClientFactory,
        _streamIdleTimeout = streamIdleTimeout;

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

  static anthropic.AnthropicClient _defaultAnthropicClientFactory({
    required String apiKey,
    required String baseUrl,
  }) {
    return anthropic.AnthropicClient(
      config: anthropic.AnthropicConfig(
        authProvider: anthropic.ApiKeyProvider(apiKey),
        baseUrl: baseUrl,
        timeout: fetchTimeout,
      ),
    );
  }

  anthropic.AnthropicClient _createAnthropicClient(ProviderEntity provider) {
    return _anthropicClientFactory(
      apiKey: provider.apiKey,
      baseUrl: _anthropicBaseUrl(provider.baseUrl),
    );
  }

  /// Messages 的请求路径由 SDK 拼成 `baseUrl + /v1/messages`，而 Athena 的
  /// provider 地址沿 OpenAI 兼容写法带 `/v1`（Anthropic 的兼容端点也是
  /// `https://api.anthropic.com/v1`）。不剥掉就会拼出 `/v1/v1/messages`。
  static String _anthropicBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.endsWith('/v1') ? url.substring(0, url.length - 3) : url;
  }

  /// 流式完成请求。自动创建 client → 重试 → close。
  ///
  /// [cancelSignal] 完成时：中断底层请求（openai_dart abortTrigger，
  /// 关闭专用流客户端）并让重试退避立即终止。
  ///
  /// 按 `provider.apiFormat` 选择协议实现（三条路径都已接入）；实现内部的
  /// 失败都以流错误呈现，保证上层的「取消优先于底层错误」归一化仍然生效。
  Stream<ChatStreamEvent> stream({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) {
    switch (provider.apiFormat) {
      case ApiFormat.chatCompletions:
        return _streamChatCompletions(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
      case ApiFormat.responses:
        return _streamResponses(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
      case ApiFormat.messages:
        return _streamMessages(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
    }
  }

  Stream<ChatStreamEvent> _streamChatCompletions({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async* {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      yield* retryStream(
        () => withIdleTimeout(
          client.chat.completions.createStream(
            request,
            abortTrigger: cancelSignal,
          ),
          _streamIdleTimeout,
        ),
        config: _retryConfig,
        abort: cancelSignal,
      );
    } finally {
      client.close();
    }
  }

  /// 非流式完成请求。自动创建 client → 重试 → close。
  Future<ChatCompletion> fetch({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) {
    switch (provider.apiFormat) {
      case ApiFormat.chatCompletions:
        return _fetchChatCompletions(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
      case ApiFormat.responses:
        return _fetchResponses(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
      case ApiFormat.messages:
        return _fetchMessages(
          provider: provider,
          request: request,
          cancelSignal: cancelSignal,
        );
    }
  }

  Future<ChatCompletion> _fetchChatCompletions({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      return await retry(
        () => client.chat.completions
            .create(request, abortTrigger: cancelSignal)
            .timeout(fetchTimeout),
        config: _retryConfig,
        abort: cancelSignal,
      );
    } finally {
      client.close();
    }
  }

  Stream<ChatStreamEvent> _streamResponses({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async* {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      yield* retryStream(
        () => withIdleTimeout(
          normalizeResponsesStream(
            client.responses.createStream(
              toResponseRequest(request, stream: true),
              abortTrigger: cancelSignal,
            ),
          ),
          _streamIdleTimeout,
        ),
        config: _retryConfig,
        abort: cancelSignal,
      );
    } finally {
      client.close();
    }
  }

  Future<ChatCompletion> _fetchResponses({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      final response = await retry(
        () => client.responses
            .create(toResponseRequest(request), abortTrigger: cancelSignal)
            .timeout(fetchTimeout),
        config: _retryConfig,
        abort: cancelSignal,
      );
      return responseToChatCompletion(response);
    } finally {
      client.close();
    }
  }

  Stream<ChatStreamEvent> _streamMessages({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async* {
    final client = _createAnthropicClient(provider);
    try {
      yield* retryStream(
        () => withIdleTimeout(
          normalizeMessagesStream(
            client.messages.createStream(
              toMessageRequest(request, stream: true),
              abortTrigger: cancelSignal,
            ),
          ),
          _streamIdleTimeout,
        ),
        config: _retryConfig,
        abort: cancelSignal,
      );
    } finally {
      client.close();
    }
  }

  Future<ChatCompletion> _fetchMessages({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
  }) async {
    final client = _createAnthropicClient(provider);
    try {
      final message = await retry(
        () => client.messages
            .create(toMessageRequest(request), abortTrigger: cancelSignal)
            .timeout(fetchTimeout),
        config: _retryConfig,
        abort: cancelSignal,
      );
      return messageToChatCompletion(message);
    } finally {
      client.close();
    }
  }
}
