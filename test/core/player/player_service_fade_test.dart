import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';
import 'manual_fade_clock.dart';

final _songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

const _ms100 = Duration(milliseconds: 100);

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late ManualFadeClock time;
  late List<double> volumes;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  bool playing() => container.read(playerServiceProvider).playing;

  /// Opens the songs playing, with both fades [fadeMs] long.
  Future<void> launch({
    int fadeMs = 100,
    int start = 0,
    FakeAudioBackend? engine,
  }) async {
    backend = engine ?? FakeAudioBackend();
    time = ManualFadeClock();
    volumes = [];
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(time.clock),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            playback: PlaybackPrefs(
              fadeOnPlayMs: fadeMs,
              fadeOnPauseMs: fadeMs,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      playerServiceProvider,
      (_, next) => volumes.add(next.volume),
    );
    await service().openTracks(_songs, start: start);
    backend.calls.clear();
  }

  tearDown(() {
    expect(volumes.toSet(), anyOf(isEmpty, {100.0}), reason: 'never faded');
  });

  test('a pause fades the engine out, then pauses it', () async {
    await launch();

    await service().playPause();
    expect(playing(), isFalse, reason: 'shows paused at once');
    expect(backend.calls, isEmpty);

    await time.advance(const Duration(milliseconds: 50));
    expect(backend.calls, ['setVolume(75.0)', 'setVolume(50.0)']);

    await time.advance(const Duration(milliseconds: 50));
    expect(backend.calls.skip(2), [
      'setVolume(25.0)',
      'setVolume(0.0)',
      'pause',
      'setVolume(100.0)',
    ]);
    expect(time.activeTimers, 0);
  });

  test('a play fades the engine in from silence', () async {
    await launch();
    await service().pause();
    backend.calls.clear();

    await service().playPause();
    expect(playing(), isTrue);
    expect(backend.calls, ['setVolume(0.0)', 'play']);

    await time.advance(_ms100);
    expect(backend.calls.skip(2), [
      'setVolume(25.0)',
      'setVolume(50.0)',
      'setVolume(75.0)',
      'setVolume(100.0)',
    ]);
  });

  test('pressing again mid fade turns it around', () async {
    await launch();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 50));
    backend.calls.clear();

    await service().playPause();
    expect(playing(), isTrue);
    // Half way out takes half the fade-in to come back.
    await time.advance(const Duration(milliseconds: 50));
    expect(backend.calls.last, 'setVolume(100.0)');
    expect(backend.calls, isNot(contains('pause')));
    expect(backend.calls, isNot(contains('play')));
    await time.advance(_ms100);
    expect(backend.calls, isNot(contains('pause')));
  });

  test(
    'a seek during a fade-out pauses and restores the volume first',
    () async {
      await launch();
      await service().playPause();
      await time.advance(const Duration(milliseconds: 25));
      backend.calls.clear();

      await service().seek(const Duration(seconds: 3));

      expect(backend.calls, [
        'pause',
        'setVolume(100.0)',
        'seek(0:00:03.000000)',
      ]);
      await time.advance(_ms100);
      expect(backend.calls, hasLength(3), reason: 'the fade is over');
    },
  );

  test('next during a fade-out pauses before the next track loads', () async {
    await launch();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    backend.calls.clear();

    await service().next();

    expect(backend.calls.take(2), ['pause', 'setVolume(100.0)']);
    expect(backend.calls[2], startsWith('open(b'));
  });

  test('stop during a fade-in restores the volume', () async {
    await launch();
    await service().pause();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    backend.calls.clear();

    await service().stop();

    expect(backend.calls.first, 'setVolume(100.0)');
    expect(backend.calls, contains('pause'));
  });

  test('the engine moving on stops the fade at the next tick', () async {
    await launch();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    backend.calls.clear();

    backend.advance();
    await time.advance(const Duration(milliseconds: 25));

    expect(backend.calls, contains('pause'));
    expect(backend.calls.last, 'setVolume(100.0)');
    final count = backend.calls.length;
    await time.advance(_ms100);
    expect(backend.calls, hasLength(count));
  });

  test('a volume set during a fade wins', () async {
    await launch();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    backend.calls.clear();

    await service().setVolume(100);
    await service().setVolume(40);
    await time.advance(const Duration(milliseconds: 25));

    // Setting the same volume again goes unnoticed; the new one ends the
    // fade: the pause it waited for goes out, the volume stays the user's.
    expect(backend.calls, [
      'setVolume(100.0)',
      'setVolume(40.0)',
      'pause',
      'setVolume(40.0)',
    ]);
    expect(container.read(playerServiceProvider).volume, 40);
    await time.advance(_ms100);
    expect(backend.calls, hasLength(4));
    volumes.clear();
  });

  test('pause() is immediate, also in the middle of a fade-out', () async {
    await launch();
    await service().pause();
    expect(backend.calls, ['pause']);

    await service().play();
    await time.advance(_ms100);
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    backend.calls.clear();

    await service().pause();
    expect(backend.calls, ['pause', 'setVolume(100.0)']);
  });

  test('a fade-out never runs past the end of the track', () async {
    await launch();
    backend.emitDuration.add(const Duration(seconds: 10));
    backend.emitPosition.add(const Duration(milliseconds: 9800));
    backend.calls.clear();

    await service().playPause();

    expect(backend.calls, ['pause']);
  });

  test('a fade-out near the end is cut to the time left', () async {
    await launch(fadeMs: 1000);
    backend.emitDuration.add(const Duration(seconds: 10));
    backend.emitPosition.add(const Duration(milliseconds: 9650));
    backend.calls.clear();

    await service().playPause();
    await time.advance(const Duration(milliseconds: 100));

    expect(backend.calls, contains('pause'));
  });

  test('no fade keeps the plain engine calls', () async {
    await launch(fadeMs: 0);
    await service().playPause();
    await service().playPause();
    expect(backend.calls, ['pause', 'play']);
    expect(time.activeTimers, 0);
  });

  test('disposing the player stops the fade without engine calls', () async {
    await launch();
    await service().playPause();
    await time.advance(const Duration(milliseconds: 25));
    final count = backend.calls.length;

    container.dispose();
    await time.advance(_ms100);

    expect(backend.calls.where((c) => c != 'dispose'), hasLength(count));
  });

  test(
    'a pause while the engine starts a fade-in lands after the play',
    () async {
      final engine = _SlowVolumeBackend();
      await launch(engine: engine);
      await service().pause();
      backend.calls.clear();

      engine.volumeGate = Completer<void>();
      final starting = service().playPause();
      await pumpMicrotasks();
      await service().pause();
      engine.volumeGate!.complete();
      engine.volumeGate = null;
      await starting;
      await time.advance(_ms100);

      expect(playing(), isFalse);
      final play = backend.calls.indexOf('play');
      expect(play, greaterThanOrEqualTo(0));
      expect(backend.calls.lastIndexOf('pause'), greaterThan(play));
      expect(backend.calls.last, 'setVolume(100.0)');
    },
  );
}

/// The fake engine with a `setVolume` that waits for [volumeGate], like a
/// real engine busy with earlier commands.
class _SlowVolumeBackend extends FakeAudioBackend {
  Completer<void>? volumeGate;

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume($volume)');
    await volumeGate?.future;
  }
}
