import 'dart:async';

import '../player_state.dart';
import 'playback_session.dart';
import 'playback_session_file.dart';

/// Creates a one-shot timer; tests pass one they can fire by hand.
typedef SessionTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

/// Saves the playback session while the app runs. A clean window close calls
/// [flush]; a kill (SIGTERM, logout) runs nothing, so the file is also kept
/// close to the live state:
/// - right away when the track changes, playback pauses or stops, or the
///   user seeks;
/// - [coalesceDelay] after queue, shuffle, repeat or volume changes, so a
///   dragged volume slider is one write;
/// - every [positionInterval] while playing, for the position.
///
/// Quitting while paused therefore restores the exact position; being killed
/// while playing loses at most [positionInterval].
///
/// The position saved is the saver's own, not the engine's last tick: right
/// after a paused open the engine reports a stray zero before it seeks to
/// the restored start. It follows ticks only while playing, and jumps on a
/// track change, pause, stop and seek.
///
/// A restored session starts [frozen]: nothing is written until a track
/// loads or the user does something ([unfreeze]). When the music drive is
/// not mounted yet, every restored file fails and the queue walks to its
/// end; saving that would replace a good session with a useless one.
class PlaybackSessionSaver {
  PlaybackSessionSaver(
    this._file, {
    PlaybackSession? initial,
    this._frozen = false,
    SessionTimerFactory? timer,
    this._upNext,
  }) : _written = initial,
       _position = initial?.position ?? Duration.zero,
       _timer = timer ?? Timer.new;

  static const coalesceDelay = Duration(milliseconds: 500);
  static const positionInterval = Duration(seconds: 10);

  final PlaybackSessionFile _file;
  final SessionTimerFactory _timer;

  /// The player's "play next" entries that have not played yet, read at
  /// every save. They only change together with the queue or the track,
  /// which already make the saver write.
  final Iterable<int> Function()? _upNext;

  /// Last snapshot loaded or written successfully: an equal one is never
  /// written again.
  PlaybackSession? _written;
  PlayerState? _state;
  Duration _position;
  bool _frozen;
  bool _disposed = false;
  Timer? _soon;
  Timer? _tick;

  bool get frozen => _frozen;

  /// Follows a change of the player state. The first call only records the
  /// state the player started with.
  void onState(PlayerState? previous, PlayerState next) {
    if (_disposed) return;
    final before = _state == null ? null : previous;
    _state = next;
    if (before == null) return;

    final trackChanged = _trackKey(before) != _trackKey(next);
    final paused = before.playing && !next.playing;
    final stopped = !before.stopped && next.stopped;
    if (next.stopped) {
      // Stopped, or ran out of tracks: the next launch starts the track over.
      _position = Duration.zero;
    } else if (trackChanged || paused || next.playing) {
      _position = next.position;
    }

    if (trackChanged || paused || stopped) {
      _saveNow();
    } else if (!identical(before.queue, next.queue) ||
        before.volume != next.volume ||
        before.volumeBeforeMute != next.volumeBeforeMute) {
      _saveSoon();
    }

    if (next.playing) {
      _tick ??= _timer(positionInterval, _onTick);
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  /// The user (or repeat one) moved the position.
  void onSeeked(Duration position) {
    if (_disposed) return;
    _position = position;
    _saveNow();
  }

  /// Lets changes reach the disk again, and saves what changed meanwhile.
  void unfreeze() {
    if (!_frozen || _disposed) return;
    _frozen = false;
    _saveSoon();
  }

  /// Gets the latest state onto the disk and waits for it, for the app's exit.
  /// The first wait lets a write already running finish: when it failed,
  /// [_written] is reset and the save after it writes the snapshot again.
  /// The saver stays usable.
  Future<void> flush() async {
    await _file.flush();
    _saveNow();
    await _file.flush();
  }

  /// Writes what is still pending and stops all timers.
  void dispose() {
    if (_disposed) return;
    _saveNow();
    _tick?.cancel();
    _tick = null;
    _disposed = true;
  }

  void _onTick() {
    _tick = null;
    if (_disposed) return;
    _saveNow();
    if (_state?.playing ?? false) _tick = _timer(positionInterval, _onTick);
  }

  void _saveSoon() {
    if (_frozen || _state == null) return;
    _soon ??= _timer(coalesceDelay, _saveNow);
  }

  void _saveNow() {
    _soon?.cancel();
    _soon = null;
    final state = _state;
    if (_frozen || _disposed || state == null) return;
    final snapshot = PlaybackSession.fromState(
      state,
      position: _position,
      upNext: _upNext?.call() ?? const [],
    );
    if (snapshot == _written) return;
    _written = snapshot;
    // Never throws. A failed write counts as not written, so the next save
    // (or dispose) writes the same snapshot again.
    unawaited(
      _file.save(snapshot).then((saved) {
        if (!saved && identical(_written, snapshot)) _written = null;
      }),
    );
  }
}

/// Which entry is current: queue position plus file, since every queue
/// change builds a new queue object.
(int, String?) _trackKey(PlayerState state) =>
    (state.queue.index, state.queue.current?.uri);
