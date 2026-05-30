import 'dart:async';
import 'dart:io';

import 'package:athena/util/retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart';

// Fast config so tests don't sleep on real backoff delays.
const _fastConfig = RetryConfig(
  maxAttempts: 3,
  baseDelay: Duration.zero,
  maxDelay: Duration.zero,
);

void main() {
  group('retry', () {
    test('retries a retryable exception and eventually succeeds', () async {
      var calls = 0;
      final result = await retry<int>(
        () async {
          calls++;
          if (calls < 3) {
            throw const SocketException('connection reset');
          }
          return 42;
        },
        config: _fastConfig,
      );
      expect(result, 42);
      expect(calls, 3);
    });

    test('exhausts maxAttempts on persistently-retryable exception, rethrows',
        () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const SocketException('connection refused');
          },
          config: _fastConfig,
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 3);
    });

    test('does NOT retry BadRequestException (rethrows after 1 call)',
        () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const BadRequestException(message: 'bad');
          },
          config: _fastConfig,
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(calls, 1);
    });

    test('does NOT retry AuthenticationException (rethrows after 1 call)',
        () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const AuthenticationException(message: 'no key');
          },
          config: _fastConfig,
        ),
        throwsA(isA<AuthenticationException>()),
      );
      expect(calls, 1);
    });

    test('does NOT retry AbortedException (user cancelled, 1 call)', () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const AbortedException();
          },
          config: _fastConfig,
        ),
        throwsA(isA<AbortedException>()),
      );
      expect(calls, 1);
    });

    test('does NOT retry plain FormatException (rethrows after 1 call)',
        () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const FormatException('nope');
          },
          config: _fastConfig,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('retries RateLimitException', () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const RateLimitException(message: 'slow down');
          },
          config: _fastConfig,
        ),
        throwsA(isA<RateLimitException>()),
      );
      expect(calls, 3);
    });

    test('retries InternalServerException', () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const InternalServerException(
              message: 'boom',
              statusCode: 500,
            );
          },
          config: _fastConfig,
        ),
        throwsA(isA<InternalServerException>()),
      );
      expect(calls, 3);
    });

    test('retries ConnectionException', () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const ConnectionException(message: 'no net');
          },
          config: _fastConfig,
        ),
        throwsA(isA<ConnectionException>()),
      );
      expect(calls, 3);
    });

    test('retries RequestTimeoutException', () async {
      var calls = 0;
      await expectLater(
        retry<int>(
          () async {
            calls++;
            throw const RequestTimeoutException(message: 'timed out');
          },
          config: _fastConfig,
        ),
        throwsA(isA<RequestTimeoutException>()),
      );
      expect(calls, 3);
    });
  });

  group('retryStream', () {
    test('retries when it fails before yielding, eventually succeeds',
        () async {
      var calls = 0;
      Stream<int> op() async* {
        calls++;
        if (calls < 3) {
          throw const SocketException('connection reset');
        }
        yield 1;
        yield 2;
      }

      final items = await retryStream<int>(op, config: _fastConfig).toList();
      expect(items, [1, 2]);
      expect(calls, 3);
    });

    test('propagates immediately once it has yielded (no retry)', () async {
      var calls = 0;
      Stream<int> op() async* {
        calls++;
        yield 1;
        throw const SocketException('connection reset');
      }

      final collected = <int>[];
      await expectLater(
        () async {
          await for (final item in retryStream<int>(op, config: _fastConfig)) {
            collected.add(item);
          }
        }(),
        throwsA(isA<SocketException>()),
      );
      expect(collected, [1]);
      expect(calls, 1);
    });

    test('does NOT retry non-retryable exception before yielding', () async {
      var calls = 0;
      Stream<int> op() async* {
        calls++;
        throw const BadRequestException(message: 'bad');
      }

      await expectLater(
        retryStream<int>(op, config: _fastConfig).toList(),
        throwsA(isA<BadRequestException>()),
      );
      expect(calls, 1);
    });
  });
}
