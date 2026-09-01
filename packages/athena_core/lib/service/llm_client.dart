import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
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
/// 职责：封装 [OpenAIClient] 生命周期（创建、请求、关闭）、
/// 重试策略、Athena 标准 Headers。所有 LLM API 调用都应通过此类。
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
  Stream<ChatStreamEvent> stream({
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
  }) async {
    var client = _createClient(provider.apiKey, provider.baseUrl);
    try {
      return await retry(
        () => client.chat.completions.create(request).timeout(fetchTimeout),
        config: _retryConfig,
      );
    } finally {
      client.close();
    }
  }
}
