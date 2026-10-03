import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/util/cancellable_stream.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cancel finishes while an async generator is waiting, and isolates late events',
    () async {
      final release = Completer<void>();
      final entered = Completer<void>();
      final cleaned = Completer<void>();
      final token = CancelToken();
      Stream<int> source() async* {
        try {
          entered.complete();
          await release.future;
          yield 42;
        } finally {
          cleaned.complete();
        }
      }

      final finished = cancellableStream(
        source(),
        token.whenCancelled,
      ).toList();
      await entered.future;
      token.cancel();
      await expectLater(
        finished.timeout(const Duration(seconds: 1)),
        throwsA(isA<CancelledException>()),
      );
      release.complete();
      await cleaned.future.timeout(const Duration(seconds: 1));
    },
  );

  test('natural completion preserves stream data', () async {
    expect(
      await cancellableStream(Stream.fromIterable([1, 2]), null).toList(),
      [1, 2],
    );
  });
}
