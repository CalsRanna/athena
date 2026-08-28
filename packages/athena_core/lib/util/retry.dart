import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart';

class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 10,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });
}

/// Retry a future-returning operation with exponential backoff + jitter.
///
/// Only retries on network-related exceptions. Non-retryable exceptions
/// (e.g. FormatException) are rethrown immediately.
///
/// [abort] 完成（取消信号）时退避立即中断并抛 [CancelledException]，
/// 不再发起新的重试请求。
Future<T> retry<T>(
  Future<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
  Future<void>? abort,
}) async {
  final random = Random();
  var attempt = 0;

  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (e) {
      if (attempt >= config.maxAttempts || !_isRetryable(e)) {
        rethrow;
      }
      final backoff = config.baseDelay.inMilliseconds *
          pow(2, attempt - 1).toInt();
      final delayMs = min(backoff + random.nextInt(500),
          config.maxDelay.inMilliseconds);
      LoggerUtil.w('Retry attempt $attempt/${config.maxAttempts} '
          'after ${delayMs}ms: ${e.runtimeType}');
      await _waitBackoff(delayMs, abort);
    }
  }
}

/// 等待退避；[abort] 提前完成则抛 [CancelledException] 中断重试。
Future<void> _waitBackoff(int delayMs, Future<void>? abort) async {
  if (abort == null) {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    return;
  }
  var aborted = false;
  final abortFlag = abort.then((_) => aborted = true, onError: (_) {});
  await Future.any([
    Future<void>.delayed(Duration(milliseconds: delayMs)),
    abortFlag,
  ]);
  if (aborted) throw const CancelledException();
}

/// Retry a stream-returning operation.
///
/// If the stream fails before yielding any data, retries the operation.
/// Once data has started flowing, failures are propagated.
///
/// [abort] 完成（取消信号）时退避立即中断并抛 [CancelledException]，
/// 不再发起新的重试请求。
Stream<T> retryStream<T>(
  Stream<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
  Future<void>? abort,
}) async* {
  final random = Random();
  var attempt = 0;

  while (true) {
    attempt++;
    var hasYielded = false;
    try {
      await for (final item in operation()) {
        yield item;
        hasYielded = true;
      }
      return;
    } catch (e) {
      if (hasYielded || !_isRetryable(e) || attempt >= config.maxAttempts) {
        rethrow;
      }
      final backoff =
          config.baseDelay.inMilliseconds * pow(2, attempt - 1).toInt();
      final delayMs =
          min(backoff + random.nextInt(500), config.maxDelay.inMilliseconds);
      LoggerUtil.w('Stream retry attempt $attempt/${config.maxAttempts} '
          'after ${delayMs}ms: ${e.runtimeType}');
      await _waitBackoff(delayMs, abort);
    }
  }
}

bool _isRetryable(Object e) {
  // dart:io / http network-level failures.
  if (e is SocketException) return true;
  if (e is http.ClientException) return true;
  if (e is TimeoutException) return true;
  if (e is HandshakeException) return true;
  if (e is TlsException) return true;
  // openai_dart typed exceptions: only transient network/server/rate-limit
  // errors are retryable. Business 4xx errors and user aborts are not.
  if (e is ConnectionException) return true;
  if (e is RequestTimeoutException) return true;
  if (e is RateLimitException) return true;
  if (e is InternalServerException) return true;
  return false;
}
