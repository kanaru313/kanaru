import 'dart:async';

import 'package:kanaru/core/player/playback_fade.dart';

/// A [FadeClock] moved by hand: [advance] moves the time and fires the
/// periodic timers that are due, once per step.
class ManualFadeClock {
  Duration now = Duration.zero;
  final _timers = <_ManualTimer>[];

  /// Timers still running.
  int get activeTimers => _timers.where((t) => t.isActive).length;

  late final FadeClock clock = (
    elapsed: () => now,
    every: (interval, tick) {
      final timer = _ManualTimer(tick);
      _timers.add(timer);
      return timer;
    },
  );

  /// Moves the time by [by] in [fadeTickInterval] steps, ticking every
  /// running timer at each step and letting microtasks run in between.
  Future<void> advance(Duration by) async {
    final end = now + by;
    while (now < end) {
      final step = end - now < fadeTickInterval ? end - now : fadeTickInterval;
      now += step;
      for (final timer in List.of(_timers)) {
        if (timer.isActive) timer.fire();
      }
      await pumpMicrotasks();
    }
    _timers.removeWhere((t) => !t.isActive);
  }
}

/// Lets queued microtasks and future callbacks run.
Future<void> pumpMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.value();
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this._tick);

  final void Function() _tick;
  bool _active = true;
  int _ticks = 0;

  void fire() {
    _ticks++;
    _tick();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;
}
