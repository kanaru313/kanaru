import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:logging/logging.dart';

import 'audio_backend.dart';
import 'audio_output_device.dart';
import 'playback_error.dart';
import 'player_service.dart';
import 'repeat_mode.dart';
import 'replay_gain_options.dart';
import 'track.dart';

final _log = Logger('UnavailableAudioBackend');

/// Stand-in for the audio engine when libmpv could not be loaded, so the
/// library stays usable. Every `open` reports one failure and a stopped
/// player. It never reports `completed` or `advanced`: those make the player
/// open the next track, which would walk the whole queue.
class UnavailableAudioBackend implements AudioBackend {
  final _advanced = StreamController<Track>.broadcast();
  final _looped = StreamController<Track>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _failed = StreamController<PlaybackError>.broadcast();

  @override
  Future<void> open(
    Track track, {
    Track? next,
    bool play = true,
    Duration start = Duration.zero,
  }) async {
    // After the call returns, so the caller has its state in place before the
    // events arrive, like with the real engine.
    // Restoring a session at startup (`play == false`) is not a user action,
    // so it stays quiet: only the paused state is reported.
    scheduleMicrotask(() {
      if (_failed.isClosed) return;
      if (play) {
        _failed.add(PlaybackError(track, 'audio engine unavailable'));
      }
      _playing.add(false);
    });
  }

  @override
  Future<void> setNext(Track? next) async {}

  @override
  Future<void> play() async {
    // The player marks itself playing before the engine confirms; with no
    // engine, answer that it is not, so it falls back to paused.
    scheduleMicrotask(() {
      if (!_playing.isClosed) _playing.add(false);
    });
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRepeat(RepeatMode mode) async {}

  @override
  Future<void> setReplayGain(ReplayGainOptions options) async {}

  @override
  Future<void> setAudioDevice(String name) async {}

  @override
  List<AudioOutputDevice> get audioDevices => const [];

  @override
  Stream<List<AudioOutputDevice>> get audioDevicesChanged =>
      const Stream.empty();

  @override
  Stream<String> get audioDeviceFailed => const Stream.empty();

  @override
  Stream<Track> get advanced => _advanced.stream;

  /// Never fed: there is no engine to loop.
  @override
  Stream<Track> get looped => _looped.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<PlaybackError> get failed => _failed.stream;

  @override
  Future<void> dispose() async {
    await Future.wait([
      _advanced.close(),
      _looped.close(),
      _playing.close(),
      _completed.close(),
      _position.close(),
      _duration.close(),
      _failed.close(),
    ]);
  }
}

/// Audio engine for the session: [create]d when the engine initialised, an
/// [UnavailableAudioBackend] when it did not or when creating it throws (the
/// libmpv library is opened by the constructor, so that can fail late).
AudioBackend audioBackendOrUnavailable(
  Ref ref, {
  required bool engineReady,
  required AudioBackend Function() create,
}) {
  AudioBackend backend;
  if (!engineReady) {
    backend = UnavailableAudioBackend();
  } else {
    try {
      backend = create();
    } catch (error, stack) {
      _log.severe('Audio engine failed to start', error, stack);
      backend = UnavailableAudioBackend();
    }
  }
  ref.onDispose(backend.dispose);
  return backend;
}

/// Provider override that installs [audioBackendOrUnavailable]. Used by
/// `main()` and by tests, so both go through the same wiring.
Override audioBackendOverride({
  required bool engineReady,
  required AudioBackend Function() create,
}) => audioBackendProvider.overrideWith(
  (ref) =>
      audioBackendOrUnavailable(ref, engineReady: engineReady, create: create),
);
