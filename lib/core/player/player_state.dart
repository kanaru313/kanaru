import 'play_queue.dart';

/// Snapshot of playback for the UI.
class PlayerState {
  PlayerState({
    PlayQueue? queue,
    this.playing = false,
    this.stopped = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.volumeBeforeMute,
    this.playthrough = 0,
    this.repeatTimes = 0,
  }) : queue = queue ?? PlayQueue();

  final PlayQueue queue;
  final bool playing;

  /// Playback was stopped, by the user or by the queue running out, as
  /// opposed to paused. Cleared by playing, jumping, seeking or a new queue.
  final bool stopped;
  final Duration position;
  final Duration duration;

  /// 0–100. Set by `PlayerService` only; the engine follows it.
  final double volume;

  /// Volume to restore on unmute; `null` when not muted.
  final double? volumeBeforeMute;

  /// Changes each time playback of the current entry starts afresh: a track
  /// is loaded (picked, opened, restored, or moved on to after a failure or
  /// removal), the engine moves on to the next one by itself, or repeat one
  /// loops it. Seeks, pause, stop and queue edits that keep the playing entry
  /// leave it alone. Compare with `!=`; a rebuilt player starts again at 0.
  final int playthrough;

  /// Extra plays of the current track still to come under a counted repeat;
  /// 0 = none. The base mode stays in `queue.repeat`, so playback goes on in
  /// it when the count runs out. Ended by any track change; not persisted.
  final int repeatTimes;

  bool get muted => volumeBeforeMute != null;

  PlayerState copyWith({
    PlayQueue? queue,
    bool? playing,
    bool? stopped,
    Duration? position,
    Duration? duration,
    double? volume,
    double? Function()? volumeBeforeMute,
    int? playthrough,
    int? repeatTimes,
  }) => PlayerState(
    queue: queue ?? this.queue,
    playing: playing ?? this.playing,
    stopped: stopped ?? this.stopped,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    volumeBeforeMute: volumeBeforeMute != null
        ? volumeBeforeMute()
        : this.volumeBeforeMute,
    playthrough: playthrough ?? this.playthrough,
    repeatTimes: repeatTimes ?? this.repeatTimes,
  );
}
