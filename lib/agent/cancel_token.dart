import 'dart:async';

class CancelledException implements Exception {
  final String reason;
  const CancelledException([this.reason = 'cancelled']);
  @override
  String toString() => 'CancelledException: $reason';
}

class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}
