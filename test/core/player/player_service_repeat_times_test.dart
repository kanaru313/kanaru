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

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  /// Opens the songs on [start] with [mode] and arms [times] extra plays.
  Future<void> counting(
    int times, {
    RepeatMode mode = RepeatMode.all,
    int start = 0,
  }) async {
    await service().setRepeat(mode);
    await service().openTracks(_songs, start: start);
    await service().setRepeatTimes(times);
    backend.calls.clear();
  }

  Future<void> loop([int at = 0]) async {
    backend.emitLooped.add(_songs[at]);
    await pumpMicrotasks();
  }

  group('counting down', () {
    test('arming loops the track in the engine, base mode stays', () async {
      await service().setRepeat(RepeatMode.all);
      await service().openTracks(_songs);
      backend.calls.clear();

      await service().setRepeatTimes(2);

      expect(backend.calls, ['setRepeat(one)']);
      expect(state().repeatTimes, 2);
      expect(state().queue.repeat, RepeatMode.all);
    });

    test('N loops, then the base mode, then a normal advance', () async {
      await counting(2);
      final before = state().playthrough;

      await loop();
      expect(state().repeatTimes, 1);
      expect(backend.calls, isEmpty);

      await loop();
      expect(state().repeatTimes, 0);
      expect(backend.calls, ['setRepeat(all)']);
      expect(state().queue.repeat, RepeatMode.all);
      expect(state().playthrough, before + 2);

      backend.advance();
      await pumpMicrotasks();
      expect(state().queue.index, 1);
      expect(state().playing, isTrue);
    });

    test('raising or lowering the number does not touch the engine', () async {
      await counting(2);

      await service().setRepeatTimes(5);
      expect(state().repeatTimes, 5);
      await service().setRepeatTimes(1);
      expect(state().repeatTimes, 1);

      expect(backend.calls, isEmpty);
    });

    test('announces each loop as a seek to the start', () async {
      await counting(2);
      final seeks = <Duration>[];
      service().seeked.listen(seeks.add);

      await loop();

      expect(seeks, [Duration.zero]);
      expect(state().position, Duration.zero);
    });

    test(
      'the last track of a shuffled pass reshuffles after the count',
      () async {
        await counting(1, mode: RepeatMode.allShuffled, start: 2);
        // Nothing is handed after the last track of a pass.
        expect(backend.next, isNull);

        await loop(2);
        expect(backend.calls, ['setRepeat(allShuffled)']);

        backend.emitCompleted.add(true);
        await pumpMicrotasks();
        expect(state().queue.index, 0);
        expect(state().queue.repeat, RepeatMode.allShuffled);
      },
    );

    test('a loop of another file is ignored', () async {
      await counting(2);

      await loop(1);

      expect(state().repeatTimes, 2);
      expect(backend.calls, isEmpty);
    });

    test('a loop after the count was cleared is ignored', () async {
      await counting(2);
      await service().setRepeat(RepeatMode.all);
      backend.calls.clear();
      final before = state().playthrough;

      await loop();

      expect(state().playthrough, before);
      expect(backend.calls, isEmpty);
    });

    test('repeat one still loops forever without a count', () async {
      await service().setRepeat(RepeatMode.one);
      await service().openTracks(_songs);
      final before = state().playthrough;

      await loop();
      await loop();

      expect(state().playthrough, before + 2);
      expect(state().queue.repeat, RepeatMode.one);
    });
  });

  group('arming', () {
    test('under repeat one the base becomes off', () async {
      await service().setRepeat(RepeatMode.one);
      await service().openTracks(_songs);
      backend.calls.clear();

      await service().setRepeatTimes(2);

      expect(state().queue.repeat, RepeatMode.off);
      expect(state().repeatTimes, 2);
      expect(backend.calls, ['setRepeat(one)']);

      await loop();
      await loop();
      expect(backend.calls, ['setRepeat(one)', 'setRepeat(off)']);
    });

    test('clamps to the maximum, 0 ends it, empty queue is a no-op', () async {
      await service().setRepeatTimes(3);
      expect(state().repeatTimes, 0);
      expect(backend.calls, isEmpty);

      await service().openTracks(_songs);
      await service().setRepeatTimes(150);
      expect(state().repeatTimes, maxRepeatTimes);
      await service().setRepeatTimes(-4);
      expect(state().repeatTimes, 0);
      expect(backend.calls.last, 'setRepeat(off)');
    });

    test('after the queue ran out it does nothing', () async {
      await service().openTracks(_songs, start: 2);
      backend.emitCompleted.add(true);
      await pumpMicrotasks();
      expect(state().stopped, isTrue);
      backend.calls.clear();

      await service().setRepeatTimes(2);

      expect(state().repeatTimes, 0);
      expect(backend.calls, isEmpty);
    });

    test('setRepeat with the base mode still ends the count', () async {
      await counting(2);

      await service().setRepeat(RepeatMode.all);

      expect(state().repeatTimes, 0);
      expect(backend.calls.first, 'setRepeat(all)');
    });

    test('cycling the mode ends the count and goes on from the base', () async {
      await counting(2);

      await service().cycleRepeat();

      expect(state().repeatTimes, 0);
      expect(state().queue.repeat, RepeatMode.allShuffled);
    });
  });

  group('a track change ends the count first', () {
    final cases = <String, Future<void> Function(PlayerService)>{
      'next': (s) => s.next(),
      'jump': (s) => s.jump(2),
      'previous': (s) => s.previous(),
      'remove the current track': (s) => s.removeTrack(1),
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        await counting(3, start: 1);

        await entry.value(service());

        expect(state().repeatTimes, 0);
        final reset = backend.calls.indexOf('setRepeat(all)');
        final open = backend.calls.indexWhere((c) => c.startsWith('open('));
        expect(reset, isNonNegative);
        expect(open, isNonNegative);
        expect(reset, lessThan(open));
        expect(state().queue.repeat, RepeatMode.all);
      });
    }

    test('the engine moving on after a failure', () async {
      await counting(3);

      backend.advance();
      await pumpMicrotasks();

      expect(state().repeatTimes, 0);
      expect(backend.calls, contains('setRepeat(all)'));
      expect(state().queue.index, 1);
    });

    test('removing the only track', () async {
      await service().setRepeat(RepeatMode.all);
      await service().openTracks([_songs[0]]);
      await service().setRepeatTimes(2);
      backend.calls.clear();

      await service().removeTrack(0);

      expect(state().repeatTimes, 0);
      expect(backend.calls, ['setRepeat(all)', 'stop']);
    });

    test('the queue running out', () async {
      await counting(2, mode: RepeatMode.off, start: 2);

      backend.emitCompleted.add(true);
      await pumpMicrotasks();

      expect(state().repeatTimes, 0);
      expect(state().stopped, isTrue);
      expect(backend.calls, contains('setRepeat(off)'));
    });
  });

  group('edits that keep the track keep the count', () {
    final cases = <String, Future<void> Function(PlayerService)>{
      'clear queue': (s) => s.clearQueue(),
      'move track': (s) => s.moveTrack(1, 2),
      'play next': (s) => s.playNext([_songs[2]]),
      'add to queue': (s) => s.addToQueue([_songs[2]]),
      'shuffle': (s) => s.setShuffle(true),
      'pause': (s) => s.pause(),
      'stop': (s) => s.stop(),
      'stop, then play': (s) async {
        await s.stop();
        await s.play();
      },
      'move to play next': (s) => s.moveToPlayNext(2),
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        await counting(3);

        await entry.value(service());

        expect(state().repeatTimes, 3);
        expect(backend.calls, isNot(contains('setRepeat(all)')));
      });
    }
  });

  group('sleep stop', () {
    test('at a loop ends the count and rests at 0', () async {
      await counting(3);
      service().setStopAfterCurrent(true);
      backend.calls.clear();

      await loop();

      expect(state().repeatTimes, 0);
      expect(state().playing, isFalse);
      expect(state().position, Duration.zero);
      expect(backend.calls, contains('setRepeat(all)'));
      expect(backend.calls, contains('pause'));
    });
  });
}
