import 'playback_error.dart';
import 'repeat_mode.dart';
import 'track.dart';

/// Thin wrapper over the audio engine. The Dart queue is the source of truth;
/// the engine only ever holds the current track and the one after it, so it
/// can move on gaplessly without mirroring the whole queue. Kept small so
/// `PlayerService` can be tested with a fake instead of libmpv.
abstract interface class AudioBackend {
  /// Starts [track] now, replacing whatever plays, with [next] queued behind
  /// it, from [start] into the track ([next] always starts at its
  /// beginning). An open that is still queued may be skipped when a newer
  /// one is queued after it.
  Future<void> open(
    Track track, {
    Track? next,
    bool play = true,
    Duration start = Duration.zero,
  });

  /// Replaces the track queued after the current one; `null` queues nothing.
  Future<void> setNext(Track? next);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// [volume] runs from 0 to 100. The app owns the volume: the engine only
  /// follows what it is told and never reports a volume of its own.
  Future<void> setVolume(double volume);

  /// Only [RepeatMode.one] matters to the engine (it loops the file, and
  /// reports each loop through [looped]); moving on to the next track is
  /// decided in Dart through [setNext].
  Future<void> setRepeat(RepeatMode mode);

  /// The queued next track became the current one on its own: the previous
  /// one ended, or failed to load and was skipped.
  Stream<Track> get advanced;

  /// The current track started over by itself under repeat one: one event per
  /// loop, with the track that looped. Never for a seek, an open or a change
  /// of track.
  Stream<Track> get looped;
  Stream<bool> get playing;

  /// Fires `true` when playback stops with nothing queued next: the last
  /// track ended, or a track failed to load with nothing after it.
  Stream<bool> get completed;
  Stream<Duration> get position;
  Stream<Duration> get duration;

  /// Tracks the engine gave up on: it moved past them without loading them.
  /// One event per track, sent before the event that moves past it.
  Stream<PlaybackError> get failed;

  Future<void> dispose();
}
