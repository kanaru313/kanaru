import 'dart:async';

import 'package:kanaru/core/player/audio_backend.dart';
import 'package:kanaru/core/player/playback_error.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

/// [AudioBackend] that records every call and lets a test push engine
/// events through the `emit*` controllers.
class FakeAudioBackend implements AudioBackend {
  /// Method calls in order, with tracks by title, e.g. `open(a, next: b)`,
  /// `setNext(c)`, `seek(0:00:00.000000)`.
  final calls = <String>[];

  /// Track queued as next by the last `open` or `setNext`.
  Track? next;

  final emitAdvanced = StreamController<Track>.broadcast(sync: true);
  final emitPlaying = StreamController<bool>.broadcast(sync: true);
  final emitCompleted = StreamController<bool>.broadcast(sync: true);
  final emitPosition = StreamController<Duration>.broadcast(sync: true);
  final emitDuration = StreamController<Duration>.broadcast(sync: true);
  final emitFailed = StreamController<PlaybackError>.broadcast(sync: true);

  /// Mimics the engine moving on to the queued next track by itself.
  void advance() => emitAdvanced.add(next!);

  /// Mimics the engine giving up on [track].
  void fail(Track track) =>
      emitFailed.add(PlaybackError(track, 'Failed to open'));

  @override
  Future<void> open(Track track, {Track? next, bool play = true}) async {
    this.next = next;
    calls.add(
      'open(${track.title}, next: ${next?.title}${play ? '' : ', paused'})',
    );
  }

  @override
  Future<void> setNext(Track? next) async {
    this.next = next;
    calls.add('setNext(${next?.title})');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async => calls.add('seek($position)');

  @override
  Future<void> setVolume(double volume) async =>
      calls.add('setVolume($volume)');

  @override
  Future<void> setRepeat(RepeatMode mode) async =>
      calls.add('setRepeat(${mode.name})');

  @override
  Stream<Track> get advanced => emitAdvanced.stream;

  @override
  Stream<bool> get playing => emitPlaying.stream;

  @override
  Stream<bool> get completed => emitCompleted.stream;

  @override
  Stream<Duration> get position => emitPosition.stream;

  @override
  Stream<Duration> get duration => emitDuration.stream;

  @override
  Stream<PlaybackError> get failed => emitFailed.stream;

  @override
  Future<void> dispose() async => calls.add('dispose');
}
