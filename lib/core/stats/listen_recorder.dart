// The only way to reach the SQLite error behind a failure in the database
// isolate; `remoteCause` is read for its codes only.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database/library_database.dart' hide Track;
import '../database/play_history_writes.dart';
import '../player/player_state.dart';
import '../player/playing_track_art.dart' show localPathOf;
import '../player/track.dart';
import 'listen_accumulator.dart';

final _log = Logger('listen_recorder');

/// Wall clock for `played_at` and a monotonic clock for listening time.
typedef ListenClock = ({DateTime Function() now, Duration Function() elapsed});

/// Where a playthrough stands with its `plays` row. `pending` means the
/// insert is queued and counts as a row; `dead` is final (not a library
/// track, the insert failed, or the history was cleared).
enum _Row { none, pending, stored, dead }

/// One playthrough of one track: from a fresh start to the next one, a stop,
/// or the recorder being switched off. The track and its path are captured at
/// the start and never re-read from later player states.
class _Playthrough {
  _Playthrough({
    required this.marker,
    required this.track,
    required this.path,
    required this.acc,
  }) : row = path == null ? _Row.dead : _Row.none;

  final int marker;
  final Track track;
  final String? path;
  final ListenAccumulator acc;
  _Row row;
  int? rowId;
  int? playedAt;

  /// First positive engine duration; the library duration until it arrives.
  Duration? lockedLength;

  /// Listening time handed to the write chain so far.
  Duration queued = Duration.zero;

  Duration? get length {
    final fallback = track.duration;
    return lockedLength ??
        (fallback != null && fallback > Duration.zero ? fallback : null);
  }
}

/// Records listens (STAT-01) of library tracks into `plays` by following the
/// player state. Never awaited on the player path: every write goes through
/// one future chain, and a failed write is logged, never thrown.
///
/// A row is inserted on the sample that crosses the listen threshold, then
/// its `listened_ms` is brought up to date when the playthrough ends, on a
/// pause with at least [pauseWriteMin] new, and every [checkpointInterval]
/// of listening. Only `plays` is written; the triggers keep `play_stats`.
class ListenRecorder {
  ListenRecorder(this._db, {required bool enabled, required ListenClock clock})
    : _recording = enabled,
      _time = clock;

  static const checkpointInterval = Duration(seconds: 30);
  static const pauseWriteMin = Duration(seconds: 5);

  final LibraryDatabase _db;
  final ListenClock _time;
  bool _recording;
  bool _disposed = false;
  PlayerState? _last;
  _Playthrough? _current;
  Future<void> _chain = Future.value();

  /// Completes when every queued write has finished.
  @visibleForTesting
  Future<void> get idle => _chain;

  /// Follows the player. Cheap: O(1) per state, no awaiting.
  void onState(PlayerState? previous, PlayerState next) {
    _last = next;
    if (!_recording || _disposed) return;
    final track = next.queue.current;
    if (next.stopped || track == null) {
      _end();
      return;
    }
    var playthrough = _current;
    if (playthrough == null || playthrough.marker != next.playthrough) {
      _end();
      playthrough = _current = _begin(next, track);
    }
    // The new queue is published a moment before the marker changes.
    if (track.uri != playthrough.track.uri) return;
    _observe(playthrough, next);
  }

  /// Turning it off ends the open playthrough with its final write; turning
  /// it on starts a new one from where the player is now.
  void setEnabled(bool enabled) {
    if (_recording == enabled) return;
    _recording = enabled;
    if (!enabled) return _end();
    final state = _last;
    if (state != null) onState(null, state);
  }

  /// Deletes the whole play history. The open playthrough is dropped without
  /// a write, and counting restarts from now when recording is on. Returns
  /// how many plays were removed, `null` when the delete failed.
  Future<int?> clearHistory() {
    _current?.row = _Row.dead;
    _current = null;
    final cleared = _enqueue(_db.clearPlayHistory);
    final state = _last;
    if (state != null) onState(null, state);
    return cleared;
  }

  /// Writes what the open playthrough has and goes inert.
  void dispose() {
    if (_disposed) return;
    _end();
    _disposed = true;
  }

  _Playthrough _begin(PlayerState state, Track track) => _Playthrough(
    marker: state.playthrough,
    track: track,
    path: localPathOf(track.uri),
    acc: ListenAccumulator(
      position: state.position,
      clock: _time.elapsed(),
      playing: state.playing,
    ),
  );

  void _observe(_Playthrough p, PlayerState state) {
    if (p.row == _Row.dead) return;
    if (p.lockedLength == null && state.duration > Duration.zero) {
      p.lockedLength = state.duration;
    }
    if (state.playing) p.playedAt ??= _time.now().millisecondsSinceEpoch;
    p.acc.sample(
      position: state.position,
      clock: _time.elapsed(),
      playing: state.playing,
    );
    final listened = p.acc.listened;
    if (p.row == _Row.none) {
      if (qualifiesAsListen(listened, p.length)) _insert(p);
      return;
    }
    final fresh = listened - p.queued;
    if (fresh >= checkpointInterval ||
        (!state.playing && fresh >= pauseWriteMin)) {
      _update(p);
    }
  }

  /// Final write of the open playthrough.
  void _end() {
    final p = _current;
    _current = null;
    if (p == null) return;
    if (p.row == _Row.none && qualifiesAsListen(p.acc.listened, p.length)) {
      _insert(p);
    } else if ((p.row == _Row.pending || p.row == _Row.stored) &&
        p.acc.listened > p.queued) {
      _update(p);
    }
  }

  void _insert(_Playthrough p) {
    p.row = _Row.pending;
    p.queued = p.acc.listened;
    final path = p.path!;
    final playedAt = p.playedAt ?? _time.now().millisecondsSinceEpoch;
    final listenedMs = p.queued.inMilliseconds;
    _enqueue(() async {
      if (p.row != _Row.pending) return;
      try {
        final id = await _db.insertLibraryPlay(
          path: path,
          playedAt: playedAt,
          listenedMs: listenedMs,
        );
        // A clear in the meantime made it dead for good.
        if (p.row != _Row.pending) return;
        p.rowId = id;
        p.row = id == null ? _Row.dead : _Row.stored;
      } on Object {
        if (p.row == _Row.pending) p.row = _Row.dead;
        rethrow;
      }
    });
  }

  void _update(_Playthrough p) {
    p.queued = p.acc.listened;
    final listenedMs = p.queued.inMilliseconds;
    _enqueue(() async {
      // The id exists once the insert ahead in the chain has run.
      final id = p.rowId;
      if (p.row != _Row.stored || id == null) return;
      await _db.setPlayListened(id, listenedMs);
    });
  }

  /// Appends [op] to the write chain. A failure is logged without the error
  /// object (its text carries the statement parameters, so the track path)
  /// and completes with `null`. Catches `Object` because a closed drift
  /// connection throws an `Error`.
  Future<T?> _enqueue<T>(Future<T> Function() op) {
    final result = _chain.then<T?>((_) async {
      try {
        return await op();
      } on Object catch (error) {
        _log.warning('Could not write the play history: ${_describe(error)}');
        return null;
      }
    });
    _chain = result.then((_) {});
    return result;
  }

  /// Error type and SQLite codes only; never the message of a statement.
  static String _describe(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is SqliteException) {
      return '${cause.runtimeType} ${cause.extendedResultCode} '
          '${cause.message}';
    }
    return '${cause.runtimeType}';
  }
}
