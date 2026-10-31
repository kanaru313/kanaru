import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import 'album_run_lookup.dart';
import 'play_queue.dart';
import 'player_service.dart';
import 'sleep_timer_album_end.dart';
import 'sleep_timer_countdown.dart';
import 'sleep_timer_player_events.dart';
import 'sleep_timer_state.dart';

export 'sleep_timer_state.dart';

final _log = Logger('player.sleep');

/// How long the minutes mode fades the engine out before it pauses.
const sleepFadeLength = Duration(seconds: 10);

/// Album keys for the end of album mode. Tests replace it.
final sleepTimerAlbumLookupProvider = Provider<AlbumRunKeyLookup>((ref) {
  // Read, not watched: the database is set once at startup.
  final db = ref.read(libraryDatabaseProvider);
  return db == null ? (_) async => const {} : albumKeyLookupFor(db);
});

final sleepTimerProvider = NotifierProvider<SleepTimer, SleepTimerState>(
  SleepTimer.new,
);

/// Pauses playback later (PLAY-14): after some minutes, after some tracks,
/// or at the end of the track, the album or the queue. Pausing keeps the queue; the track-based
/// modes leave the next track loaded paused at its start. Session only.
///
/// The minutes mode counts wall time, also while playback is paused (only
/// [pauseCounting] holds it). Over the last [sleepFadeLength], while
/// playing, the engine fades to silence; at zero the player pauses without
/// a fade and gets the user's volume back. Expiring while paused just turns
/// the timer off. The other modes keep [PlayerService.stopAfterCurrent] in
/// line with the queue and turn off when the player reports the stop.
class SleepTimer extends Notifier<SleepTimerState> {
  late PlayerService _player;
  late SleepTimerAlbumEnd _albumEnd;
  late SleepTimerCountdown _countdown;
  final _events = SleepTimerPlayerEvents();

  /// The countdown started a sleep fade since it was last armed (start,
  /// added time, resumed count). A fade that then ends early was
  /// interrupted by the user (play/pause, volume, seek, a new track) and is
  /// not started again: the timer pauses at zero without one.
  bool _fadeStarted = false;

  @override
  SleepTimerState build() {
    _countdown = SleepTimerCountdown(ref.read(playbackFadeClockProvider));
    _player = ref.read(playerServiceProvider.notifier);
    _albumEnd = SleepTimerAlbumEnd(ref.read(sleepTimerAlbumLookupProvider));
    _followEvents();
    // Every track change or queue edit (and a player rebuild, which makes a
    // new queue) may move where playback has to stop.
    ref.listen(playerServiceProvider.select((s) => s.queue), (_, _) {
      _followEvents();
      _syncStopAfterCurrent();
    });
    ref.onDispose(() {
      _countdown.stop();
      _events.cancel();
      _albumEnd.dispose();
      // Synchronous, so it never clears a stop a new build set right after.
      _player.releaseStopAfterCurrent();
      // The fade needs the player's state, which a provider being disposed
      // may not read. A new build cannot start a sleep fade before the
      // microtask runs: its countdown is at least a minute long.
      final player = _player;
      scheduleMicrotask(player.endSleepFade);
    });
    return const SleepTimerState.off();
  }

  /// Pauses after [minutes], kept within 1 to 720.
  void startMinutes(int minutes) {
    _reset();
    final length = Duration(
      minutes: minutes.clamp(sleepTimerMinMinutes, sleepTimerMaxMinutes),
    );
    state = SleepTimerState(mode: SleepTimerMode.minutes, remaining: length);
    _countdown.start(length, _tick);
    _tick();
  }

  /// Pauses after [count] tracks (1 to 20, the current one included) have
  /// played to their end. Skipping does not use a track up.
  void startTracks(int count) {
    _reset();
    state = SleepTimerState(
      mode: SleepTimerMode.tracks,
      tracksLeft: count.clamp(sleepTimerMinTracks, sleepTimerMaxTracks),
    );
    _syncStopAfterCurrent();
  }

  void startEndOfTrack() => _startStopMode(SleepTimerMode.endOfTrack);
  void startEndOfAlbum() => _startStopMode(SleepTimerMode.endOfAlbum);
  void startEndOfQueue() => _startStopMode(SleepTimerMode.endOfQueue);

  /// Adds [minutes] (or takes them off when negative) in the minutes mode,
  /// up to 720 minutes left. Taking off is refused unless more than that is
  /// left ([SleepTimerState.canSubtract]).
  void addMinutes(int minutes) {
    if (state.mode != SleepTimerMode.minutes || minutes == 0) return;
    if (minutes < 0 && !state.canSubtract(-minutes)) return;
    var left = _countdown.left + Duration(minutes: minutes);
    const most = Duration(minutes: sleepTimerMaxMinutes);
    if (left > most) left = most;
    _countdown.set(left);
    _fadeStarted = false;
    if (!state.countingPaused) return _tick();
    state = SleepTimerState(
      mode: SleepTimerMode.minutes,
      remaining: _wholeSeconds(left),
      countingPaused: true,
    );
  }

  /// Adds [delta] tracks (or takes them off when negative) in the tracks
  /// mode, within 1 to 20 left.
  void addTracks(int delta) {
    if (state.mode != SleepTimerMode.tracks || delta == 0) return;
    if (delta < 0 && !state.canRemoveTrack) return;
    state = SleepTimerState(
      mode: SleepTimerMode.tracks,
      tracksLeft: (state.tracksLeft + delta).clamp(
        sleepTimerMinTracks,
        sleepTimerMaxTracks,
      ),
    );
    _syncStopAfterCurrent();
  }

  /// Holds the minutes countdown; a sleep fade under way is undone.
  void pauseCounting() {
    if (state.mode != SleepTimerMode.minutes || state.countingPaused) return;
    _countdown.hold();
    _player.endSleepFade();
    state = SleepTimerState(
      mode: SleepTimerMode.minutes,
      remaining: _wholeSeconds(_countdown.left),
      countingPaused: true,
    );
  }

  void resumeCounting() {
    if (state.mode != SleepTimerMode.minutes || !state.countingPaused) return;
    _fadeStarted = false;
    _countdown.start(_countdown.left, _tick);
    _tick();
  }

  /// Turns the timer off; playback goes on as if it never ran.
  void cancel() {
    _reset();
    state = const SleepTimerState.off();
  }

  void _startStopMode(SleepTimerMode mode) {
    _reset();
    state = SleepTimerState(mode: mode);
    _syncStopAfterCurrent();
  }

  /// Undoes whatever the running mode asked of the player.
  void _reset() {
    _countdown.stop();
    _fadeStarted = false;
    _albumEnd.cancel();
    _player.setStopAfterCurrent(false);
    _player.endSleepFade();
  }

  /// Sets the player's stop after the current track for the mode.
  void _syncStopAfterCurrent() {
    final queue = ref.read(playerServiceProvider).queue;
    switch (state.mode) {
      case null || SleepTimerMode.minutes:
        return;
      case SleepTimerMode.tracks:
        _player.setStopAfterCurrent(state.tracksLeft <= 1);
      case SleepTimerMode.endOfTrack:
        _player.setStopAfterCurrent(true);
      case SleepTimerMode.endOfQueue:
        _player.setStopAfterCurrent(_isLast(queue));
      case SleepTimerMode.endOfAlbum:
        // Until a new pair is decided, the last decision stays.
        _albumEnd.check(queue, (last) {
          if (state.mode == SleepTimerMode.endOfAlbum) {
            _player.setStopAfterCurrent(last);
          }
        });
    }
  }

  static bool _isLast(PlayQueue queue) =>
      !queue.isEmpty && queue.index == queue.order.length - 1;

  void _followEvents() =>
      _events.follow(_player, onStop: _turnOff, onTrackEnd: _onTrackEnd);

  /// A track ended by itself in the tracks mode: one less to go, or the
  /// timer is done when the queue ran out first.
  void _onTrackEnd() {
    if (state.mode != SleepTimerMode.tracks) return;
    if (ref.read(playerServiceProvider).stopped) return _turnOff();
    if (state.tracksLeft > 1) {
      state = SleepTimerState(
        mode: SleepTimerMode.tracks,
        tracksLeft: state.tracksLeft - 1,
      );
      _syncStopAfterCurrent();
    }
  }

  /// The player stopped for a track-based mode.
  void _turnOff() {
    if (state.mode == null || state.mode == SleepTimerMode.minutes) return;
    _albumEnd.cancel();
    state = const SleepTimerState.off();
  }

  /// Publishes the time left and fades or pauses when it is due.
  void _tick() {
    final left = _countdown.left;
    if (left <= Duration.zero) return _expire();
    state = SleepTimerState(
      mode: SleepTimerMode.minutes,
      remaining: _wholeSeconds(left),
    );
    if (left > sleepFadeLength) {
      // Time was added during the fade: undo it and arm it again.
      _player.endSleepFade();
      _fadeStarted = false;
    } else if (!_fadeStarted && ref.read(playerServiceProvider).playing) {
      _fadeStarted = true;
      _player.fadeOutForSleep(left);
    }
  }

  void _expire() {
    _countdown.stop();
    state = const SleepTimerState.off();
    if (!ref.read(playerServiceProvider).playing) {
      _player.endSleepFade();
      return;
    }
    // A pause without a fade settles the sleep fade: the engine pauses,
    // then gets the user's volume back.
    unawaited(
      _player.pause().catchError((Object error, StackTrace stack) {
        _log.warning('Could not pause for the sleep timer', error, stack);
      }),
    );
  }

  static Duration _wholeSeconds(Duration d) => Duration(
    seconds: (d.inMicroseconds / Duration.microsecondsPerSecond).ceil(),
  );
}
