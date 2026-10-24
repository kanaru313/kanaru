import 'dart:async';

import 'playback_fade.dart';

/// How often the minutes mode checks the time.
const sleepTimerTick = Duration(milliseconds: 250);

/// Wall-time countdown of the sleep timer's minutes mode on a [FadeClock].
/// The time left comes from a deadline, not from counting ticks, so a late
/// or extra tick never makes it drift. It can be held, and then keeps the
/// time that was left.
class SleepTimerCountdown {
  SleepTimerCountdown(this._clock);

  final FadeClock _clock;
  Timer? _ticker;
  Duration _deadline = Duration.zero;

  /// Time left while held; `null` while counting or stopped.
  Duration? _held;

  /// Time left now; negative once the deadline passed.
  Duration get left => _held ?? _deadline - _clock.elapsed();

  /// Counts down [left] from now, calling [tick] every [sleepTimerTick].
  void start(Duration left, void Function() tick) {
    stop();
    _deadline = _clock.elapsed() + left;
    _ticker = _clock.every(sleepTimerTick, tick);
  }

  /// Holds the countdown at the time left now.
  void hold() {
    final now = left;
    stop();
    _held = now;
  }

  /// Sets the time left, counting or held.
  void set(Duration left) {
    if (_held != null) {
      _held = left;
    } else {
      _deadline = _clock.elapsed() + left;
    }
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _held = null;
  }
}
