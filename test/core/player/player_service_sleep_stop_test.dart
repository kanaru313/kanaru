import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';
import 'manual_fade_clock.dart';

final _songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late int stops;
  late ManualFadeClock time;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);

  void listenStops() => service().sleepStops.listen((_) => stops++);

  setUp(() {
    backend = FakeAudioBackend();
    time = ManualFadeClock();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(time.clock),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    stops = 0;
    listenStops();
  });
  tearDown(() => container.dispose());

  /// Opens the songs at [start] and turns the stop on.
  Future<void> openAndStop({int start = 0}) async {
    await service().openTracks(_songs, start: start);
    service().setStopAfterCurrent(true);
    await pumpMicrotasks();
    backend.calls.clear();
  }

  test(
    'turning the stop on withdraws the next track, off gives it back',
    () async {
      await service().openTracks(_songs);
      backend.calls.clear();

      service().setStopAfterCurrent(true);
      await pumpMicrotasks();
      expect(service().stopAfterCurrent, isTrue);
      expect(backend.calls, ['setNext(null)']);

      service().setStopAfterCurrent(false);
      await pumpMicrotasks();
      expect(backend.calls, ['setNext(null)', 'setNext(b)']);
    },
  );

  test('a track opened with the stop on gets no next track', () async {
    await openAndStop();
    await service().jump(1);
    expect(backend.calls, ['open(b, next: null)']);
  });

  test('the end of the track loads the next one paused, queue kept', () async {
    await openAndStop();

    backend.emitCompleted.add(true);
    await pumpMicrotasks();

    expect(stops, 1);
    expect(service().stopAfterCurrent, isFalse);
    expect(backend.calls, ['open(b, next: c, paused)']);
    expect(state().playing, isFalse);
    expect(state().stopped, isFalse);
    expect(state().queue.current, _songs[1]);
    expect(state().queue.tracks, _songs);
  });

  test('repeat all on the last track loads the first one paused', () async {
    await service().setRepeat(RepeatMode.all);
    await openAndStop(start: 2);

    backend.emitCompleted.add(true);
    await pumpMicrotasks();

    expect(stops, 1);
    expect(backend.calls, ['open(a, next: b, paused)']);
    expect(state().queue.index, 0);
    expect(state().playing, isFalse);
  });

  test('the end of a queue that does not repeat ends as without it', () async {
    await openAndStop(start: 2);
    backend.emitDuration.add(const Duration(seconds: 90));
    backend.emitPosition.add(const Duration(seconds: 90));

    backend.emitCompleted.add(true);
    await pumpMicrotasks();

    expect(stops, 1);
    expect(backend.calls, isEmpty);
    expect(state().stopped, isTrue);
    expect(state().playing, isFalse);
    expect(state().position, const Duration(seconds: 90));
  });

  test(
    'repeat one rests at 0 of the looped track, next handed again',
    () async {
      await service().setRepeat(RepeatMode.one);
      await openAndStop();
      final seeks = <Duration>[];
      service().seeked.listen(seeks.add);

      backend.emitLooped.add(_songs[0]);
      await pumpMicrotasks();

      expect(stops, 1);
      // The engine played on into the loop before the pause landed: the
      // seek brings it back to the start.
      expect(backend.calls, ['pause', 'setNext(b)', 'seek(${Duration.zero})']);
      expect(seeks, [Duration.zero], reason: 'only the loop is announced');
      expect(state().playing, isFalse);
      expect(state().position, Duration.zero);
      expect(state().queue.current, _songs[0]);
    },
  );

  test(
    'a move to a next track handed before the stop pauses it at 0',
    () async {
      await service().openTracks(_songs);
      // The engine still has b queued: the withdrawal did not land yet.
      service().setStopAfterCurrent(true);
      backend.calls.clear();
      final seeks = <Duration>[];
      service().seeked.listen(seeks.add);

      backend.emitAdvanced.add(_songs[1]);
      await pumpMicrotasks();

      expect(seeks, isEmpty);

      expect(stops, 1);
      expect(state().queue.current, _songs[1]);
      expect(state().playing, isFalse);
      expect(state().position, Duration.zero);
      expect(backend.calls, ['setNext(c)', 'pause', 'seek(${Duration.zero})']);
    },
  );

  test('a move without the stop plays on', () async {
    await service().openTracks(_songs);
    backend.calls.clear();

    backend.advance();
    await pumpMicrotasks();

    expect(stops, 0);
    expect(state().playing, isTrue);
    expect(backend.calls, ['setNext(c)']);
  });

  test('a stop happens once: the next track then plays on', () async {
    await openAndStop();
    backend.emitCompleted.add(true);
    await pumpMicrotasks();
    await service().play();
    backend.calls.clear();

    backend.advance();
    await pumpMicrotasks();

    expect(stops, 1);
    expect(state().playing, isTrue);
    expect(state().queue.index, 2);
  });

  test('a fade-out under way settles before the rest at 0', () async {
    await service().setRepeat(RepeatMode.one);
    await openAndStop();
    service().fadeOutForSleep(const Duration(seconds: 10));
    await time.advance(const Duration(seconds: 1));
    expect(service().sleepFading, isTrue);
    expect(state().playing, isTrue, reason: 'the sleep fade keeps playing');

    backend.emitLooped.add(_songs[0]);
    await pumpMicrotasks();

    expect(service().sleepFading, isFalse);
    expect(backend.calls, contains('setVolume(100.0)'));
    expect(state().playing, isFalse);
  });

  test('releasing the stop hands the next track back later', () async {
    await openAndStop();

    service().releaseStopAfterCurrent();
    expect(service().stopAfterCurrent, isFalse);
    expect(backend.calls, isEmpty);
    await pumpMicrotasks();
    expect(backend.calls, ['setNext(b)']);
  });

  test('a stop turned on again before the release lands stays', () async {
    await openAndStop();

    service().releaseStopAfterCurrent();
    service().setStopAfterCurrent(true);
    await pumpMicrotasks();

    expect(service().stopAfterCurrent, isTrue);
    expect(backend.calls, ['setNext(null)']);
  });

  test('a rebuild turns the stop off', () async {
    await openAndStop();

    container.invalidate(playerServiceProvider);
    state();
    expect(service().stopAfterCurrent, isFalse);
  });

  group('trackEnds', trackEndsTests);
}

/// `trackEnds` contract, apart from the stop tests above.
void trackEndsTests() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late int ends;
  late int stops;

  PlayerService service() => container.read(playerServiceProvider.notifier);

  setUp(() async {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    ends = 0;
    stops = 0;
    service().trackEnds.listen((_) => ends++);
    service().sleepStops.listen((_) => stops++);
    await service().openTracks(_songs);
    await pumpMicrotasks();
  });
  tearDown(() => container.dispose());

  test('fires once for an advance, a completion and a loop', () async {
    backend.advance();
    expect(ends, 1);
    backend.emitCompleted.add(true);
    expect(ends, 2);
    await service().setRepeat(RepeatMode.one);
    backend.emitLooped.add(service().state.queue.current!);
    expect(ends, 3);
  });

  test('never fires for skip, jump or a failed track', () async {
    await service().next();
    await service().jump(2);
    await service().previous();
    expect(ends, 0);
    backend.fail(_songs[1]);
    backend.advance();
    expect(ends, 0);
  });

  test('a sleep stop is not a track end', () async {
    backend.emitDuration.add(const Duration(seconds: 100));
    // With the stop on no next track is handed, so an advance is the engine
    // moving on to a track handed before the stop.
    final cases = <String, Future<void> Function()>{
      'advance': () async => backend.emitAdvanced.add(_songs[1]),
      'completed': () async => backend.emitCompleted.add(true),
      'loop': () async {
        await service().setRepeat(RepeatMode.one);
        backend.emitLooped.add(service().state.queue.current!);
      },
    };
    var expectedStops = 0;
    for (final MapEntry(:key, :value) in cases.entries) {
      service().setStopAfterCurrent(true);
      await pumpMicrotasks();
      await value();
      expect(ends, 0, reason: key);
      expect(stops, ++expectedStops, reason: key);
    }
  });

  test('a rebuild makes a new stream', () async {
    final before = service().trackEnds;
    container.invalidate(playerServiceProvider);
    container.read(playerServiceProvider);
    expect(service().trackEnds == before, isFalse);
    backend.advance();
    expect(ends, 0);
  });
}
