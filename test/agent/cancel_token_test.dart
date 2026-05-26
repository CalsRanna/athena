import 'package:athena/agent/cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancelToken', () {
    test('isCancelled is false initially', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel() flips isCancelled to true', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() completes whenCancelled future', () async {
      final token = CancelToken();
      final future = token.whenCancelled;
      token.cancel();
      await expectLater(future, completes);
    });

    test('cancel() is idempotent', () {
      final token = CancelToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled() throws when cancelled', () {
      final token = CancelToken();
      token.cancel();
      expect(token.throwIfCancelled, throwsA(isA<CancelledException>()));
    });

    test('throwIfCancelled() is a no-op when not cancelled', () {
      final token = CancelToken();
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('CancelledException.toString includes reason', () {
      const e = CancelledException('user clicked stop');
      expect(e.toString(), contains('user clicked stop'));
    });
  });
}
