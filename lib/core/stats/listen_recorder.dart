import 'package:flutter/foundation.dart' show visibleForTesting;

import '../database/library_database.dart' hide Track;
import '../database/play_history_writes.dart' show PlayHistoryWrites;
import '../player/player_state.dart';
import '../player/playing_track_art.dart' show localPathOf;
import '../player/track.dart';
import 'listen_accumulator.dart';
import 'listen_playthrough.dart';
import 'play_row_writer.dart';
import 'play_write_chain.dart';

/// Wall clock for `played_at` and a monotonic clock for listening time.
typedef ListenClock = ({DateTime Function() now, Duration Function() elapsed});

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
  ListenPlaythrough? _current;

  /// Marker of the last playthrough that reached the listen threshold.
  int? _countedMarker;

  /// Marker the recorder was switched back on in, after it was already
  /// counted: that playthrough is not opened again.
  int? _skippedMarker;
  final _writes = PlayWriteChain();
  late final _rows = PlayRowWriter(_db, _writes, _time.now);

  /// Completes when every queued write has finished.
  @visibleForTesting
  Future<void> get idle => _writes.idle;

  /// Follows the player. Cheap: O(1) per state, no awaiting.
  void onState(PlayerState? previous, PlayerState next) {
    _last = next;
    if (!_recording || _disposed) return;
    final track = next.queue.current;
    if (next.stopped || track == null) {
      _skippedMarker = null;
      _end();
      return;
    }
    var playthrough = _current;
    if (playthrough == null || playthrough.marker != next.playthrough) {
      if (playthrough == null && next.playthrough == _skippedMarker) return;
      _end();
      playthrough = _current = _begin(next, track);
    }
    // The new queue is published a moment before the marker changes.
    if (track.uri != playthrough.track.uri) return;
    _observe(playthrough, next);
  }

  /// Turning it off ends the open playthrough with its final write; turning
  /// it on starts a new one from where the player is now, unless the playing
  /// one was already counted: then the next fresh start is the next one.
  void setEnabled(bool enabled) {
    if (_recording == enabled) return;
    _recording = enabled;
    if (!enabled) return _end();
    final state = _last;
    if (state == null) return;
    if (state.playthrough == _countedMarker) {
      _skippedMarker = state.playthrough;
      return;
    }
    onState(null, state);
  }

  /// Deletes the whole play history. Counting restarts from now when
  /// recording is on, and the open playthrough is dropped without a write once
  /// the delete worked; a failed delete gives it back as it was. Returns how
  /// many plays were removed, `null` when the delete failed.
  Future<int?> clearHistory() {
    final open = _current;
    final counted = _countedMarker;
    _current = null;
    _countedMarker = null;
    // A counted playthrough stays closed until the delete has worked.
    final restartLater = _skippedMarker != null;
    if (!restartLater) _restart();
    return _writes.enqueue(_db.clearPlayHistory).then((removed) {
      if (removed == null) {
        _restoreAfterFailedClear(open, counted);
      } else if (restartLater) {
        _skippedMarker = null;
        _restart();
      }
      return removed;
    });
  }

  void _restart() {
    final state = _last;
    if (state != null) onState(null, state);
  }

  /// The history is intact, so the playthrough [open] when the clear began
  /// goes on. Counting that began meanwhile is dropped, unless it already
  /// reached a row of its own.
  void _restoreAfterFailedClear(ListenPlaythrough? open, int? counted) {
    _countedMarker ??= counted;
    if (open == null) return;
    final meanwhile = _current;
    if (meanwhile != null &&
        meanwhile.marker == open.marker &&
        meanwhile.row == PlayRow.none) {
      _current = open;
      return;
    }
    // It ended in the meantime: give it its final write.
    _current = open;
    _end();
    _current = meanwhile;
  }

  /// Writes what the open playthrough has and goes inert.
  void dispose() {
    if (_disposed) return;
    _end();
    _disposed = true;
  }

  ListenPlaythrough _begin(PlayerState state, Track track) => ListenPlaythrough(
    marker: state.playthrough,
    track: track,
    path: localPathOf(track.uri),
    acc: ListenAccumulator(
      position: state.position,
      clock: _time.elapsed(),
      playing: state.playing,
    ),
  );

  void _observe(ListenPlaythrough p, PlayerState state) {
    if (p.row == PlayRow.dead) return;
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
    if (p.row == PlayRow.none) {
      if (qualifiesAsListen(listened, p.length)) _insertRow(p);
      return;
    }
    final fresh = listened - p.queued;
    if (fresh >= checkpointInterval ||
        (!state.playing && fresh >= pauseWriteMin)) {
      _rows.update(p);
    }
  }

  void _insertRow(ListenPlaythrough p) {
    _countedMarker = p.marker;
    _rows.insert(p);
  }

  /// Final write of the open playthrough.
  void _end() {
    final p = _current;
    _current = null;
    if (p == null) return;
    if (p.row == PlayRow.none && qualifiesAsListen(p.acc.listened, p.length)) {
      _insertRow(p);
    } else if ((p.row == PlayRow.pending || p.row == PlayRow.stored) &&
        p.acc.listened > p.queued) {
      _rows.update(p);
    }
  }
}
