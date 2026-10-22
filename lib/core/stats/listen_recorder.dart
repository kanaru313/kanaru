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

  /// Marker of the playthrough that had a row when recording was switched
  /// off; consumed by the next switch on.
  int? _switchedOffMarker;

  /// Marker the recorder was switched back on in, after it was already
  /// counted: that playthrough is not opened again.
  int? _skippedMarker;

  /// The delete running now, if any. Nothing is counted meanwhile.
  Future<int?>? _clearing;
  final _writes = PlayWriteChain();
  late final _rows = PlayRowWriter(_db, _writes, _time.now);

  /// Completes when every queued write has finished.
  @visibleForTesting
  Future<void> get idle => _writes.idle;

  /// Follows the player. Cheap: O(1) per state, no awaiting.
  void onState(PlayerState? previous, PlayerState next) {
    _last = next;
    if (next.stopped) _switchedOffMarker = null;
    if (!_recording || _disposed || _clearing != null) return;
    final track = next.queue.current;
    if (next.stopped || track == null) {
      _skippedMarker = null;
      _end();
      return;
    }
    var playthrough = _current;
    if (playthrough == null || playthrough.marker != next.playthrough) {
      if (playthrough == null && next.playthrough == _skippedMarker) return;
      _skippedMarker = null;
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
    if (!enabled) {
      final open = _current;
      _end();
      _switchedOffMarker = open != null && _hasRow(open) ? open.marker : null;
      return;
    }
    final state = _last;
    final closed = _switchedOffMarker;
    _switchedOffMarker = null;
    if (state == null) return;
    if (state.playthrough == closed) _skippedMarker = closed;
    onState(null, state);
  }

  /// Deletes the whole play history. Nothing is counted while the delete
  /// runs. When it worked, the open playthrough is dropped without a write and
  /// counting restarts from then; when it failed, the history is intact and
  /// the open playthrough goes on. Returns how many plays were removed, `null`
  /// when the delete failed.
  Future<int?> clearHistory() {
    final running = _clearing;
    if (running != null) return running;
    final open = _current;
    _current = null;
    final cleared = _writes.enqueue(_db.clearPlayHistory).then((removed) {
      _clearing = null;
      if (removed != null) {
        _skippedMarker = _switchedOffMarker = null;
      } else if (open != null) {
        _resume(open);
      }
      _restart();
      return removed;
    });
    return _clearing = cleared;
  }

  static bool _hasRow(ListenPlaythrough p) =>
      p.row == PlayRow.pending || p.row == PlayRow.stored;

  void _restart() {
    final state = _last;
    if (state != null) onState(null, state);
  }

  /// After a failed delete: [open] goes on when it is still the playing one,
  /// else it gets its final write.
  void _resume(ListenPlaythrough open) {
    final state = _last;
    final playing =
        _recording &&
        !_disposed &&
        state != null &&
        !state.stopped &&
        state.playthrough == open.marker;
    // Switched off while the delete ran: the switch-on must skip this play.
    if (!_recording && _hasRow(open)) _switchedOffMarker = open.marker;
    _current = open;
    if (!playing) _end();
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
      if (qualifiesAsListen(listened, p.length)) _rows.insert(p);
      return;
    }
    final fresh = listened - p.queued;
    if (fresh >= checkpointInterval ||
        (!state.playing && fresh >= pauseWriteMin)) {
      _rows.update(p);
    }
  }

  /// Final write of the open playthrough.
  void _end() {
    final p = _current;
    _current = null;
    if (p == null) return;
    if (p.row == PlayRow.none && qualifiesAsListen(p.acc.listened, p.length)) {
      _rows.insert(p);
    } else if ((p.row == PlayRow.pending || p.row == PlayRow.stored) &&
        p.acc.listened > p.queued) {
      _rows.update(p);
    }
  }
}
