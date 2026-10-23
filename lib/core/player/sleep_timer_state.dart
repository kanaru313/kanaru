import 'package:flutter/foundation.dart';

/// When the sleep timer pauses playback.
enum SleepTimerMode {
  /// After a number of minutes, fading out over the last seconds.
  minutes,

  /// When the current track ends.
  endOfTrack,

  /// When the next track in play order belongs to another album, or none
  /// follows.
  endOfAlbum,

  /// When the last track in play order ends, whatever repeat says.
  endOfQueue,
}

/// Fewest and most minutes the minutes mode counts down from.
const sleepTimerMinMinutes = 1;
const sleepTimerMaxMinutes = 720;

/// Snapshot of the sleep timer for the UI. Session only: never saved.
@immutable
class SleepTimerState {
  const SleepTimerState.off()
    : mode = null,
      remaining = Duration.zero,
      countingPaused = false;

  const SleepTimerState({
    required SleepTimerMode this.mode,
    this.remaining = Duration.zero,
    this.countingPaused = false,
  });

  /// `null` while the timer is off.
  final SleepTimerMode? mode;

  /// Time left in the minutes mode, in whole seconds rounded up; zero in
  /// the other modes.
  final Duration remaining;

  /// The minutes countdown is on hold (only in the minutes mode).
  final bool countingPaused;

  bool get active => mode != null;

  /// Whether taking [minutes] off still leaves time: subtracting is refused
  /// once no more than that is left, so it never turns the timer off.
  bool canSubtract(int minutes) =>
      mode == SleepTimerMode.minutes && remaining > Duration(minutes: minutes);

  @override
  bool operator ==(Object other) =>
      other is SleepTimerState &&
      other.mode == mode &&
      other.remaining == remaining &&
      other.countingPaused == countingPaused;

  @override
  int get hashCode => Object.hash(mode, remaining, countingPaused);

  @override
  String toString() =>
      'SleepTimerState($mode, $remaining${countingPaused ? ', paused' : ''})';
}
