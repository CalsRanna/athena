import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:athena/util/logger_util.dart';
import 'package:http/http.dart' as http;

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
Future<T> retry<T>(
  Future<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
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
      LoggerUtil.w('Retry attempt $attempt/$config.maxAttempts '
          'after ${delayMs}ms: ${e.runtimeType}');
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}

/// Retry a stream-returning operation.
///
/// If the stream fails before yielding any data, retries the operation.
/// Once data has started flowing, failures are propagated.
Stream<T> retryStream<T>(
  Stream<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
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
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}

bool _isRetryable(Object e) {
  if (e is SocketException) return true;
  if (e is http.ClientException) return true;
  if (e is TimeoutException) return true;
  if (e is HandshakeException) return true;
  if (e is TlsException) return true;
  final msg = e.toString().toLowerCase();
  if (msg.contains('connection') && (msg.contains('reset') || msg.contains('refused') || msg.contains('closed'))) return true;
  return false;
}
