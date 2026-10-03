import 'package:athena_core/entity/rewind_result.dart';

/// Exclusive ownership of a session across frontends, separate from write locks.
abstract interface class SessionActivityLease {
  Future<void> release();
}

abstract interface class SessionRewindRepository {
  /// Fails immediately when another frontend owns the session.
  Future<SessionActivityLease> acquireSessionActivity(String chatId);

  /// Atomically rewinds to before a persisted user message, preserving a snapshot.
  /// The caller must hold the session activity lease until this future completes.
  Future<RewindResult> rewindToUserMessage(String chatId, String messageId);
}
