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

  bool get muted => volumeBeforeMute != null;

  PlayerState copyWith({
    PlayQueue? queue,
    bool? playing,
    bool? stopped,
    Duration? position,
    Duration? duration,
    double? volume,
    double? Function()? volumeBeforeMute,
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
  );
}
