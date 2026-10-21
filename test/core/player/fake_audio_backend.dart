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

  /// When set, `open` and `setNext` throw it (an [Exception] is an engine
  /// failure; an [Error] a bug) after recording their call.
  Object? engineError;

  /// Mimics the engine moving on to the queued next track by itself.
  void advance() => emitAdvanced.add(next!);

  /// Mimics the engine giving up on [track].
  void fail(Track track) =>
      emitFailed.add(PlaybackError(track, 'Failed to open'));

  /// When set, `open` records its call and then waits for this to complete,
  /// like the real engine loading a file. A `setNext` that arrives meanwhile
  /// waits for the `open` to finish, then applies, as in the engine's command
  /// chain.
  Completer<void>? openGate;
  Future<void>? _openDone;

  @override
  Future<void> open(
    Track track, {
    Track? next,
    bool play = true,
    Duration start = Duration.zero,
  }) async {
    this.next = next;
    final paused = play ? '' : ', paused';
    final at = start > Duration.zero ? ', at $start' : '';
    calls.add('open(${track.title}, next: ${next?.title}$paused$at)');
    if (engineError != null) throw engineError!;
    final gate = openGate;
    if (gate == null) return;
    final done = _openDone = gate.future;
    try {
      await done;
    } finally {
      if (identical(_openDone, done)) _openDone = null;
    }
  }

  @override
  Future<void> setNext(Track? next) async {
    // Without a pending open the call applies at once, not a tick later.
    final open = _openDone;
    if (open != null) await open;
    this.next = next;
    calls.add('setNext(${next?.title})');
    if (engineError != null) throw engineError!;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  /// When set, `seek` records its call and then waits for this to complete.
  Completer<void>? seekGate;

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek($position)');
    await seekGate?.future;
  }

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
