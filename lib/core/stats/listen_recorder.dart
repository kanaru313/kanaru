import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;

import '../database/library_database.dart' hide Track;
import '../database/play_history_writes.dart' show PlayHistoryWrites;
import '../player/player_state.dart';
import '../player/playing_track_art.dart' show localPathOf;
import '../player/track.dart';
import 'listen_accumulator.dart';
import 'listen_clear_scope.dart';
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
  ListenRecorder(
    this._db, {
    required bool enabled,
    required ListenClock clock,
    this.threshold = ListenThreshold.standard,
  }) : _recording = enabled,
       _time = clock;

  static const checkpointInterval = Duration(seconds: 30);
  static const pauseWriteMin = Duration(seconds: 5);

  final LibraryDatabase _db;
  final ListenClock _time;

  /// When a play counts. A change applies from the next player state, also
  /// to the playthrough under way; a row already written stays.
  ListenThreshold threshold;
  bool _recording;
  bool _disposed = false;
  PlayerState? _last;
  ListenPlaythrough? _current;

  /// The playthrough that had a row when recording was switched off; consumed
  /// by the next switch on.
  PlaythroughMark? _switchedOff;

  /// The playthrough the recorder was switched back on in, after it was
  /// already counted: it is not opened again.
  PlaythroughMark? _skipped;

  /// Clears queued or running. Nothing is counted meanwhile.
  int _pendingClears = 0;

  /// The open playthrough, parked while clears are pending: each clear
  /// decides, when its delete has run, whether it is dropped or kept.
  ListenPlaythrough? _held;
  final _clearingNow = ValueNotifier<bool>(false);
  final _clearedPlays = StreamController<ClearBounds>.broadcast();
  final _writes = PlayWriteChain();
  late final _rows = PlayRowWriter(_db, _writes, _time.now);

  /// Whether a clear is queued or running, for the screens that start one.
  ValueListenable<bool> get clearing => _clearingNow;

  /// The range of every clear that deleted, after its delete worked.
  Stream<ClearBounds> get cleared => _clearedPlays.stream;

  /// Completes when every queued write has finished.
  @visibleForTesting
  Future<void> get idle => _writes.idle;

  /// Follows the player. Cheap: O(1) per state, no awaiting.
  void onState(PlayerState? previous, PlayerState next) {
    _last = next;
    if (next.stopped) _switchedOff = null;
    if (!_recording || _disposed || _pendingClears > 0) return;
    final track = next.queue.current;
    if (next.stopped || track == null) {
      _skipped = null;
      _end();
      return;
    }
    var playthrough = _current;
    if (playthrough == null || playthrough.marker != next.playthrough) {
      if (playthrough == null && next.playthrough == _skipped?.marker) return;
      _skipped = null;
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
      _switchedOff = open != null && _hasRow(open) ? _markOf(open) : null;
      return;
    }
    final state = _last;
    final closed = _switchedOff;
    _switchedOff = null;
    if (state == null) return;
    if (state.playthrough == closed?.marker) _skipped = closed;
    onState(null, state);
  }

  /// Deletes the plays that started in `[from, to)` (epoch ms; a missing side
  /// is open, none at all is the whole history). Nothing is counted while a
  /// clear is pending; clears run one after another, each with its own result.
  ///
  /// Whether the open playthrough, and the ones behind the switch-off and
  /// skip markers, are affected is decided when the delete has run, by the
  /// time each started: an affected one is dropped without a write and
  /// counting restarts from then; one outside the range keeps its row and goes
  /// on. When the delete failed the history is intact and the open
  /// playthrough goes on. Returns how many plays were removed, `null` when the
  /// delete failed.
  Future<int?> clearHistory({int? from, int? to}) {
    final bounds = (from: from, to: to);
    if (_pendingClears++ == 0) {
      _held = _current;
      _current = null;
      _setClearing(true);
    }
    return _writes.enqueue(() => _deleteRange(bounds)).then((removed) {
      if (--_pendingClears == 0) _finishClears();
      return removed;
    });
  }

  Future<int> _deleteRange(ClearBounds bounds) async {
    final removed = await _db.clearPlayHistory(
      from: bounds.from,
      to: bounds.to,
    );
    if (clearTouches(bounds, _held?.playedAt)) _held = null;
    if (_skipped != null && clearTouches(bounds, _skipped!.playedAt)) {
      _skipped = null;
    }
    if (_switchedOff != null && clearTouches(bounds, _switchedOff!.playedAt)) {
      _switchedOff = null;
    }
    _clearedPlays.add(bounds);
    return removed;
  }

  /// The last pending clear is done: a playthrough that survived goes on (or
  /// gets its final write if the player left it), then counting restarts.
  void _finishClears() {
    final kept = _held;
    _held = null;
    if (kept != null) _resume(kept);
    _setClearing(false);
    _restart();
  }

  void _setClearing(bool value) {
    if (!_disposed) _clearingNow.value = value;
  }

  static PlaythroughMark _markOf(ListenPlaythrough p) =>
      PlaythroughMark(p.marker, p.playedAt);

  static bool _hasRow(ListenPlaythrough p) =>
      p.row == PlayRow.pending || p.row == PlayRow.stored;

  void _restart() {
    final state = _last;
    if (state != null) onState(null, state);
  }

  /// After the last pending clear (failed or not): [open] goes on when it is still the playing one,
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
    if (!_recording && _hasRow(open)) _switchedOff = _markOf(open);
    _current = open;
    if (!playing) _end();
  }

  /// Writes the open playthrough's progress now and waits for every queued
  /// write, for the app's exit. Unlike [dispose] it is a checkpoint: the
  /// playthrough stays open and recording goes on, so a flush that is not
  /// followed by an exit counts nothing twice (the same row is updated).
  /// Listened time is as of the last player state.
  Future<void> flush() async {
    // A pending clear parks the open play; wait until it is back (or gone).
    while (_pendingClears > 0) {
      await _writes.idle;
      await Future<void>.delayed(Duration.zero);
    }
    final open = _current;
    if (!_disposed && open != null) _writeProgress(open);
    await _writes.idle;
  }

  /// Writes what the open playthrough has and goes inert.
  void dispose() {
    if (_disposed) return;
    _end();
    _disposed = true;
    _clearingNow.dispose();
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
      if (qualifiesAsListen(listened, p.length, threshold)) _rows.insert(p);
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
    if (p != null) _writeProgress(p);
  }

  /// Inserts [p] when it qualifies, or brings its stored row up to date.
  void _writeProgress(ListenPlaythrough p) {
    if (p.row == PlayRow.none &&
        qualifiesAsListen(p.acc.listened, p.length, threshold)) {
      _rows.insert(p);
    } else if ((p.row == PlayRow.pending || p.row == PlayRow.stored) &&
        p.acc.listened > p.queued) {
      _rows.update(p);
    }
  }
}
