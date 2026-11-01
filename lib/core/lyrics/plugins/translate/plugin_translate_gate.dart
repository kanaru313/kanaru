import 'dart:async';
import 'dart:collection';

/// A waiter of [PluginTranslateGate] was dropped before it sent anything
/// because the job that wanted the run was replaced meanwhile. Not a
/// failure: nothing was billed and nothing is shown.
class TranslationSuperseded implements Exception {
  const TranslationSuperseded();

  @override
  String toString() => 'TranslationSuperseded';
}

/// Lets one translate run at a time go through, process-wide. Translate runs
/// are slow and billed, and a job is never cancelled once it started, so a
/// plain queue would make the song that plays now wait behind every skipped
/// song and bill them all. Instead each waiter says whether it is still
/// wanted; at the front of the line one that is not is dropped before it
/// sends.
class PluginTranslateGate {
  final _waiters = Queue<_Waiter>();
  bool _busy = false;

  /// How many runs wait for their turn (not the one running).
  int get waiting => _waiters.length;

  /// Waits for the turn, then runs [task]. Throws [TranslationSuperseded]
  /// without running it when [stillWanted] is false at the front of the line.
  Future<T> run<T>(
    bool Function() stillWanted,
    Future<T> Function() task,
  ) async {
    if (_busy) {
      final waiter = _Waiter();
      _waiters.add(waiter);
      await waiter.turn.future;
    } else {
      _busy = true;
    }
    // The turn is held until the finally block hands it on.
    try {
      if (!stillWanted()) throw const TranslationSuperseded();
      return await task();
    } finally {
      if (_waiters.isEmpty) {
        _busy = false;
      } else {
        _waiters.removeFirst().turn.complete();
      }
    }
  }
}

class _Waiter {
  final turn = Completer<void>();
}
