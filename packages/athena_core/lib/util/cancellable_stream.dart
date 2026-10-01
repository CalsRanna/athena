import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';

/// Cancels the underlying subscription, including a pending moveNext.
Stream<T> cancellableStream<T>(
  Stream<T> stream,
  Future<void>? cancelSignal,
) async* {
  final iterator = StreamIterator<T>(stream);
  var completed = false;
  var cancelled = false;
  if (cancelSignal != null) {
    unawaited(
      cancelSignal.then((_) {
        if (completed) return;
        cancelled = true;
        unawaited(iterator.cancel());
      }),
    );
  }
  try {
    while (await iterator.moveNext()) {
      if (cancelled) throw const CancelledException();
      yield iterator.current;
    }
    if (cancelled) throw const CancelledException();
  } catch (_) {
    if (cancelled) throw const CancelledException();
    rethrow;
  } finally {
    completed = true;
    await iterator.cancel();
  }
}
