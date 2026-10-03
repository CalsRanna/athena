import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/util/logger_util.dart';

/// Cancels the underlying subscription, including a pending moveNext.
Stream<T> cancellableStream<T>(
  Stream<T> stream,
  Future<void>? cancelSignal,
) async* {
  final iterator = StreamIterator<T>(stream);
  var completed = false;
  var cancelled = false;
  void cancelInBackground() {
    unawaited(
      iterator.cancel().catchError((Object error) {
        LoggerUtil.w('Cancelled stream cleanup failed: $error');
      }),
    );
  }

  if (cancelSignal != null) {
    unawaited(
      cancelSignal.then((_) {
        if (completed) return;
        cancelled = true;
        cancelInBackground();
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
    // async* 源可能正在等待不响应 abort 的 SDK/网络。取消 moveNext 已
    // 隔离后续事件，不能再等待它的清理 future，否则 run 仍会挂在取消中。
    if (cancelled) {
      cancelInBackground();
    } else {
      await iterator.cancel();
    }
  }
}
