import 'dart:async';

import 'package:logging/logging.dart';

import 'audio_backend.dart';
import 'playback_fade.dart';
import 'player_state.dart';

final _log = Logger('player.fade');

/// A fade-out stops this long before the end of the track, so the engine
/// does not move on to the next one while it fades.
const fadeEndMargin = Duration(milliseconds: 250);

/// A fade shorter than this is skipped: the change happens at once.
const shortestFade = Duration(milliseconds: 50);

/// The engine side of the play/pause fades (PLAY-02) for one player build:
/// the player flips its state, this ramps the engine's volume with
/// [AudioBackend.setVolume] and pauses the engine when a fade-out ends. The
/// player's own volume ([PlayerState.volume]) never changes; the engine gets
/// it scaled by the fade's gain, and gets it back unscaled whenever a fade
/// ends or is settled.
///
/// A fade stops on its own, settling at once, when what it was started for
/// changes: another playthrough (a new track, repeat one looping) or a new
/// volume or mute. The sleep fade-out ([fadeOutForSleep]) is the exception
/// for a new playthrough: it goes on into the next track.
class PlayPauseFader {
  PlayPauseFader({
    required FadeClock clock,
    required this._backend,
    required this._state,
  }) {
    _ramp = PlaybackFade(
      clock: clock,
      // Scaled from the volume as it is now; muted stays silent.
      apply: (gain) => _backend.setVolume(_state().volume * gain),
      check: _stillApplies,
      onInterrupted: settle,
    );
  }

  final AudioBackend _backend;
  final PlayerState Function() _state;
  late final PlaybackFade _ramp;

  /// The engine still plays and pauses when the fade-out ends.
  bool _pauseAfterFade = false;

  /// Bumped whenever a fade starts or settles, so an await that resumes
  /// after one sees it lost its turn.
  int _turn = 0;
  bool _disposed = false;

  /// The running fade, or the silence it left, is the sleep fade-out.
  bool _sleepFade = false;

  /// What the running fade was started for.
  ({int playthrough, double volume, double? beforeMute})? _for;

  /// A pause is waiting for a fade-out: the engine still plays.
  bool get pausePending => _pauseAfterFade;

  /// A fade is running or left the engine's volume scaled.
  bool get busy => _ramp.active || _ramp.gain != 1;

  /// A sleep fade-out is running or left the engine's volume lowered.
  bool get sleepFading => _sleepFade;

  /// Pauses the engine, fading out over [fadeMs] scaled by the volume left
  /// (a fade-in turned around takes only as long as it had come). The fade
  /// never runs past the end of the track, where the engine would move on.
  /// The player has already flipped its state; the returned future does not
  /// wait for the fade.
  Future<void> pause(int fadeMs) async {
    if (_disposed) return;
    _sleepFade = false;
    final state = _state();
    var length = Duration(
      microseconds: (fadeMs * 1000 * (busy ? _ramp.gain : 1)).round(),
    );
    if (state.duration > Duration.zero) {
      final left = state.duration - state.position - fadeEndMargin;
      if (left < length) length = left;
    }
    if (length < shortestFade) {
      // Nothing to fade from: exactly the plain pause.
      if (!busy && !_pauseAfterFade) return _backend.pause();
      _pauseAfterFade = true;
      settle();
      return;
    }
    final turn = ++_turn;
    _pauseAfterFade = true;
    _mark();
    _ramp.run(
      to: 0,
      length: length,
      onDone: () {
        if (turn != _turn || !_pauseAfterFade) return;
        _pauseAfterFade = false;
        _ramp.gain = 1;
        _call(_backend.pause);
        _call(() => _backend.setVolume(_state().volume));
      },
    );
  }

  /// Plays the engine, fading in over [fadeMs]. During a fade-out the engine
  /// never paused, so the fade turns around from where it is.
  Future<void> play(int fadeMs) async {
    if (_disposed) return;
    _sleepFade = false;
    if (_pauseAfterFade) {
      _pauseAfterFade = false;
      _turn++;
      _mark();
      _ramp.run(
        to: 1,
        length: Duration(
          microseconds: (fadeMs * 1000 * (1 - _ramp.gain)).round(),
        ),
        onDone: () {},
      );
      return;
    }
    if (fadeMs <= 0) {
      if (busy) settle();
      return _backend.play();
    }
    _ramp.cancel();
    final turn = ++_turn;
    _ramp.gain = 0;
    // Both are sent before awaiting, so a pause or settle that comes while
    // the engine works lands after the play, never before it.
    await Future.wait([_backend.setVolume(0), _backend.play()]);
    // A pause, seek or track change while the engine started settled it.
    if (turn != _turn || _disposed) return;
    _mark();
    _ramp.run(
      to: 1,
      length: Duration(milliseconds: fadeMs),
      onDone: () {},
    );
  }

  /// Ramps the engine's volume from where it is to silence over [length]
  /// for the sleep timer, without pausing the engine or touching the
  /// player's state: the track plays on silently until the player pauses,
  /// whose settle sends the user's volume back. Unlike the other fades it
  /// goes on across a new playthrough (the engine moving on to the next
  /// track); a volume or mute change still settles it. Does nothing while a
  /// pause waits for its fade-out, which goes to silence already.
  void fadeOutForSleep(Duration length) {
    if (_disposed || _pauseAfterFade) return;
    _turn++;
    _sleepFade = true;
    _mark();
    _ramp.run(to: 0, length: length, onDone: () {});
  }

  /// Ends a sleep fade-out at once, sending the user's volume back. Any
  /// other fade is left alone.
  void endSleepFade() {
    if (_sleepFade) settle();
  }

  /// Ends any fade at once: a pause it was waiting for reaches the engine
  /// now, then the user's volume. Synchronous, so both go out before
  /// whatever the player sends next (a seek, the next track).
  void settle() {
    if (_disposed) return;
    _turn++;
    _ramp.cancel();
    _sleepFade = false;
    final pause = _pauseAfterFade;
    _pauseAfterFade = false;
    if (pause) _call(_backend.pause);
    if (_ramp.gain != 1) {
      _ramp.gain = 1;
      _call(() => _backend.setVolume(_state().volume));
    }
  }

  /// Stops for good without touching the engine: its player build is gone.
  void dispose() {
    _disposed = true;
    _ramp.cancel();
    _pauseAfterFade = false;
    _sleepFade = false;
  }

  void _mark() {
    final state = _state();
    _for = (
      playthrough: state.playthrough,
      volume: state.volume,
      beforeMute: state.volumeBeforeMute,
    );
  }

  bool _stillApplies() {
    final marked = _for;
    final state = _state();
    return !_disposed &&
        marked != null &&
        (_sleepFade || marked.playthrough == state.playthrough) &&
        marked.volume == state.volume &&
        marked.beforeMute == state.volumeBeforeMute;
  }

  /// A fire-and-forget engine call; a failure is only logged.
  void _call(Future<void> Function() call) {
    Future<void>.sync(call).catchError((Object error) {
      // The type only, like the other engine calls.
      _log.warning('Fade engine call failed (${error.runtimeType})');
    });
  }
}
