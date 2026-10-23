import 'dart:async';

/// Counts the writes a playlist page has in flight, and lets a play or a
/// queue pick wait until there are none, so it reads the queue the database
/// ends up with.
class PlaylistWriteGate {
  var _inFlight = 0;
  final _waiting = <Completer<void>>[];

  /// Whether a write is running.
  bool get busy => _inFlight > 0;

  /// A write starts. True when it is the first of a batch.
  bool begin() => _inFlight++ == 0;

  /// A write ends and the waiters are released when it was the last one.
  /// True when it was.
  bool end() {
    if (--_inFlight > 0) return false;
    _releaseWaiting();
    return true;
  }

  /// Completes when no write is running.
  Future<void> afterWrites() {
    if (!busy) return Future.value();
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  /// Releases the waiters; whoever wakes up finds the page gone. Safe to
  /// call again, and a write that ends later finds nobody waiting.
  void dispose() => _releaseWaiting();

  void _releaseWaiting() {
    final waiting = [..._waiting];
    _waiting.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) completer.complete();
    }
  }
}
