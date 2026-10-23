import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('player.fade');

/// Time source of the play/pause fades: a monotonic clock and a periodic
/// timer. Tests replace it with a clock they move by hand.
typedef FadeClock = ({
  Duration Function() elapsed,
  Timer Function(Duration interval, void Function() tick) every,
});

final playbackFadeClockProvider = Provider<FadeClock>((ref) {
  final stopwatch = Stopwatch()..start();
  return (
    elapsed: () => stopwatch.elapsed,
    every: (interval, tick) => Timer.periodic(interval, (_) => tick()),
  );
});

/// How often a fade sends a new volume.
const fadeTickInterval = Duration(milliseconds: 25);

/// A volume ramp for fading in on play and out on pause (PLAY-02). It only
/// computes a gain between 0 (silent) and 1 (the user's volume) and hands it
/// to [apply]; the player scales its volume by it, so the volume the user
/// set is never changed by a fade.
///
/// At most one [apply] is in flight: a tick that comes while the engine is
/// still busy with the last one replaces the waiting value instead of
/// queueing another command. [check] runs before every step; when it says
/// the fade no longer belongs to what plays (another track, a new volume),
/// the fade stops and [onInterrupted] runs instead of the step.
class PlaybackFade {
  PlaybackFade({
    required this.clock,
    required this.apply,
    required this.check,
    required this.onInterrupted,
  });

  final FadeClock clock;

  /// Sends a gain to the engine.
  final Future<void> Function(double gain) apply;

  /// Whether the fade still belongs to what plays.
  final bool Function() check;

  /// Runs when [check] said no; the fade has stopped already.
  final void Function() onInterrupted;

  /// The gain last computed; 1 when no fade ever ran.
  double gain = 1;

  Timer? _timer;
  double _from = 1;
  double _to = 1;
  Duration _start = Duration.zero;
  Duration _length = Duration.zero;

  /// The `onDone` of the ramp that reached its end, called once the engine
  /// has the last value.
  void Function()? _whenIdle;
  bool _sending = false;
  double? _waiting;

  /// A ramp is running.
  bool get active => _timer != null;

  /// A ramp toward silence is running (a pause is waiting for it).
  bool get towardSilence => active && _to == 0;

  /// Ramps from the current [gain] to [to] in [length], then calls [onDone]
  /// once the last value reached the engine. A [length] of zero or less
  /// sets [to] at once. Replaces a ramp that is running, without its
  /// `onDone`.
  void run({
    required double to,
    required Duration length,
    required void Function() onDone,
  }) {
    _timer?.cancel();
    _timer = null;
    _whenIdle = null;
    _from = gain;
    _to = to;
    _start = clock.elapsed();
    _length = length;
    if (length <= Duration.zero || _from == to) {
      _finish(onDone);
      return;
    }
    _timer = clock.every(fadeTickInterval, () => _tick(onDone));
  }

  /// Stops the ramp where it is, without its `onDone` and without sending
  /// anything more. A volume already in flight still lands.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _waiting = null;
    _whenIdle = null;
  }

  void _tick(void Function() onDone) {
    if (!check()) {
      cancel();
      onInterrupted();
      return;
    }
    final passed = clock.elapsed() - _start;
    if (passed >= _length) {
      _timer?.cancel();
      _timer = null;
      _finish(onDone);
      return;
    }
    gain =
        _from + (_to - _from) * passed.inMicroseconds / _length.inMicroseconds;
    _send(gain);
  }

  void _finish(void Function() onDone) {
    gain = _to;
    _whenIdle = onDone;
    _send(_to);
  }

  void _send(double value) {
    if (_sending) {
      _waiting = value;
      return;
    }
    _sending = true;
    Future<void>.sync(() => apply(value))
        .catchError((Object error) {
          // The type only, like the other engine calls.
          _log.warning('Fade volume failed (${error.runtimeType})');
        })
        .whenComplete(() {
          _sending = false;
          final next = _waiting;
          _waiting = null;
          if (next != null) return _send(next);
          final done = _whenIdle;
          _whenIdle = null;
          done?.call();
        });
  }
}
