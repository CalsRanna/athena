import 'dart:async';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
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

/// 统一的 LLM API 客户端。
///
/// 职责：按 `provider.apiFormat` 分派到具体协议实现，并封装 [OpenAIClient]
/// 生命周期（创建、请求、关闭）、重试策略、Athena 标准 Headers。
/// 所有 LLM API 调用都应通过此类。
///
/// 目前已接入 Chat Completions 与 Responses 两条路径；Messages 的接入点在
/// [stream] / [fetch] 的 switch 分支里，未接入的协议会显式抛出
/// [UnsupportedError] 而不是静默回落。
class LlmClient {
  final OpenAIClientFactory _clientFactory;
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
    Duration streamIdleTimeout = streamIdleTimeout,
  })  : _retryConfig = retryConfig,
        _clientFactory = clientFactory ?? _defaultClientFactory,
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

  /// 流式完成请求。自动创建 client → 重试 → close。
  ///
  /// [cancelSignal] 完成时：中断底层请求（openai_dart abortTrigger，
  /// 关闭专用流客户端）并让重试退避立即终止。
  ///
  /// 按 `provider.apiFormat` 选择协议实现；未接入的协议以流错误呈现
  /// （而不是同步抛出），保证上层的「取消优先于底层错误」归一化仍然生效。
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
        return Stream.error(_unsupportedApiFormat(provider));
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
        return Future.error(_unsupportedApiFormat(provider));
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
      return toChatCompletion(response);
    } finally {
      client.close();
    }
  }

  /// 未接入的协议：显式失败，不静默回落成 Chat Completions。
  ///
  /// 回落会把 Responses / Messages 端点当 OpenAI 兼容端点使用，用户拿到的是
  /// 难以定位的 400 / 404；这里直接说明配置与恢复方式。
  UnsupportedError _unsupportedApiFormat(ProviderEntity provider) {
    return UnsupportedError(
      'Provider「${provider.name}」的 API 格式为 ${provider.apiFormat.value}，'
      '该协议的原生请求适配尚未接入；请先改回 chat_completions。',
    );
  }
}
