import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/queue_history_writes.dart';
import '../player/play_queue.dart';
import '../player/player_service.dart';
import '../player/playing_track_art.dart' show localPathOf;

final _log = Logger('queue_history');

/// Keeps the queues the user replaces (see [QueueHistoryRecorder]); null
/// without a library. The app shell keeps it alive.
final queueHistoryRecorderProvider = Provider<QueueHistoryRecorder?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return null;
  final recorder = QueueHistoryRecorder(ref, db);
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Saves every queue the player announces on `PlayerService.replacedQueues`
/// (an open that swaps the queue out, clearing the queue) as a saved queue:
/// its local files in play order. A queue holding the same files in the same
/// order as the one playing when the event is heard is left out: tapping
/// another song of the same album replaces the queue with itself.
///
/// Writes run one after another, in the order the queues were replaced.
/// A failed write is logged and dropped; it never reaches the player.
class QueueHistoryRecorder {
  QueueHistoryRecorder(this._ref, this._db, {int Function()? clock})
    : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _stateSubscription = _ref.listen(
      playerServiceProvider,
      (_, _) => _listenToReplaced(),
      onError: (_, _) {},
    );
    _listenToReplaced();
  }

  final Ref _ref;
  final LibraryDatabase _db;
  final int Function() _clock;
  ProviderSubscription<Object?>? _stateSubscription;
  Stream<PlayQueue>? _stream;
  StreamSubscription<PlayQueue>? _subscription;
  Future<void> _tail = Future.value();
  bool _disposed = false;

  /// Resolves once every write started so far has finished.
  Future<void> get idle => _tail;

  /// Follows `PlayerService.replacedQueues`. The service makes a new stream
  /// when its provider rebuilds and closes the old one, so a finished stream
  /// means: look for the new one (the same as MPRIS follows `seeked`).
  void _listenToReplaced() {
    if (_disposed || _subscription != null) return;
    final Stream<PlayQueue> stream;
    try {
      stream = _ref.read(playerServiceProvider.notifier).replacedQueues;
    } catch (error) {
      _log.warning('Not following replaced queues', error);
      return;
    }
    if (stream == _stream) return;
    _stream = stream;
    _subscription = stream.listen(
      _onReplaced,
      onDone: () {
        _subscription = null;
        Timer.run(_listenToReplaced);
      },
    );
  }

  void _onReplaced(PlayQueue previous) {
    final paths = queuePaths(previous);
    // The queue playing now is used only to leave out a copy of itself; it
    // may be a later replacement than the one of this event.
    final playing = _ref.read(playerServiceProvider).queue;
    if (_samePaths(paths, queuePaths(playing))) return;
    final now = _clock();
    _tail = _tail.then((_) async {
      if (_disposed) return;
      try {
        await _db.recordQueueSnapshot(paths, now: now);
      } catch (error, stack) {
        _log.warning('Saving a replaced queue failed', error, stack);
      }
    });
  }

  void dispose() {
    _disposed = true;
    _stateSubscription?.close();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

/// The local files of [queue] in play order. Queue URIs of local files are
/// already canonical (library rows, files opened through `localAudioPath`,
/// restored sessions of those); anything else is left out.
List<String> queuePaths(PlayQueue queue) => [
  for (final track in queue.tracks) ?localPathOf(track.uri),
];

bool _samePaths(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
