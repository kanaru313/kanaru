import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/audio_backend.dart';
import 'package:kanaru/core/player/playback_error.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/player/unavailable_audio_backend.dart';

import 'fake_audio_backend.dart';

/// Backend that counts the tracks it is asked to open.
class _CountingUnavailable extends UnavailableAudioBackend {
  int opens = 0;

  @override
  Future<void> open(Track track, {Track? next, bool play = true}) {
    opens++;
    return super.open(track, next: next, play: play);
  }
}

/// The override `main()` installs, with the two failure points injectable.
ProviderContainer containerWith({
  required bool engineReady,
  required AudioBackend Function() create,
}) {
  final container = ProviderContainer(
    overrides: [audioBackendOverride(engineReady: engineReady, create: create)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('UnavailableAudioBackend', () {
    test('reports one failure and a stopped player per open', () async {
      final backend = UnavailableAudioBackend();
      final errors = <PlaybackError>[];
      final playing = <bool>[];
      backend.failed.listen(errors.add);
      backend.playing.listen(playing.add);
      final completed = <bool>[];
      final advanced = <Track>[];
      backend.completed.listen(completed.add);
      backend.advanced.listen(advanced.add);

      final track = Track.fromPath('/music/a.mp3');
      await backend.open(track, next: Track.fromPath('/music/b.mp3'));
      await Future<void>.delayed(Duration.zero);

      expect(errors.single.track, track);
      expect(playing, [false]);
      expect(completed, isEmpty);
      expect(advanced, isEmpty);
      await backend.dispose();
    });

    test('open after dispose does not throw', () async {
      final backend = UnavailableAudioBackend();
      await backend.open(Track.fromPath('/music/a.mp3'));
      await backend.dispose();
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('audioBackendOrUnavailable', () {
    test('never calls create when the engine did not initialise', () {
      var created = 0;
      final container = containerWith(
        engineReady: false,
        create: () {
          created++;
          return FakeAudioBackend();
        },
      );

      expect(
        container.read(audioBackendProvider),
        isA<UnavailableAudioBackend>(),
      );
      expect(created, 0);
    });

    test('falls back when create throws', () {
      final container = containerWith(
        engineReady: true,
        create: () => throw StateError('libmpv missing'),
      );

      expect(
        container.read(audioBackendProvider),
        isA<UnavailableAudioBackend>(),
      );
    });

    test('keeps a backend that was created and disposes it with the scope', () {
      final fake = FakeAudioBackend();
      final container = containerWith(engineReady: true, create: () => fake);

      expect(container.read(audioBackendProvider), same(fake));
      container.dispose();
      expect(fake.calls, contains('dispose'));
    });
  });

  for (final initFailed in [true, false]) {
    test('tapping a song in a 10 000 track queue opens once and errors once '
        '(${initFailed ? 'init failed' : 'constructor failed'})', () async {
      final container = containerWith(
        engineReady: !initFailed,
        create: () => throw StateError('no libmpv'),
      );
      final backend = container.read(audioBackendProvider);
      expect(backend, isA<UnavailableAudioBackend>());

      final service = container.read(playerServiceProvider.notifier);
      final errors = <PlaybackError>[];
      service.errors.listen(errors.add);
      final tracks = [
        for (var i = 0; i < 10000; i++) Track.fromPath('/music/$i.mp3'),
      ];

      await service.openTracks(tracks, start: 5000);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(errors, hasLength(1));
      expect(errors.single.track, tracks[5000]);
      final state = container.read(playerServiceProvider);
      expect(state.playing, isFalse);
      expect(state.queue.index, 5000);
    });
  }

  test('play without an engine falls back to paused', () async {
    final container = containerWith(
      engineReady: false,
      create: () => throw StateError('unused'),
    );
    final service = container.read(playerServiceProvider.notifier);
    await service.openTracks([Track.fromPath('/music/a.mp3')]);
    await Future<void>.delayed(Duration.zero);

    await service.playPause();
    expect(container.read(playerServiceProvider).playing, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(playerServiceProvider).playing, isFalse);
  });

  test('a queue tap reaches the engine exactly once', () async {
    final counting = _CountingUnavailable();
    final container = containerWith(engineReady: true, create: () => counting);
    final service = container.read(playerServiceProvider.notifier);
    final errors = <PlaybackError>[];
    service.errors.listen(errors.add);

    await service.openTracks([
      for (var i = 0; i < 10000; i++) Track.fromPath('/music/$i.mp3'),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(counting.opens, 1);
    expect(errors, hasLength(1));
  });
}
