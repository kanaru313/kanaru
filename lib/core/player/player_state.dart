import 'play_queue.dart';

/// Snapshot of playback for the UI.
class PlayerState {
  PlayerState({
    PlayQueue? queue,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.volumeBeforeMute,
  }) : queue = queue ?? PlayQueue();

  final PlayQueue queue;
  final bool playing;
  final Duration position;
  final Duration duration;

  /// 0–100.
  final double volume;

  /// Volume to restore on unmute; `null` when not muted.
  final double? volumeBeforeMute;

  bool get muted => volumeBeforeMute != null;

  PlayerState copyWith({
    PlayQueue? queue,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? volume,
    double? Function()? volumeBeforeMute,
  }) => PlayerState(
    queue: queue ?? this.queue,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    volumeBeforeMute: volumeBeforeMute != null
        ? volumeBeforeMute()
        : this.volumeBeforeMute,
  );
}
