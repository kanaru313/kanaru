import 'dart:math';

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
  for (final name in ['a', 'b', 'c', 'd']) Track.fromPath('/music/$name.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);
  List<String> titles() => [for (final t in state().queue.tracks) t.title];

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(5)),
        ),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  /// Repeat all shuffled with the four songs, on the last one.
  Future<void> onLastTrack() async {
    await service().setRepeat(RepeatMode.allShuffled);
    await service().openTracks(_songs, start: 3);
    backend.calls.clear();
  }

  Future<void> finishTrack() async {
    backend.emitCompleted.add(true);
    await pumpMicrotasks();
  }

  group('the end of a pass', () {
    test('the engine is handed no next track on the last one', () async {
      await service().setRepeat(RepeatMode.allShuffled);
      await service().openTracks(_songs, start: 2);
      expect(backend.next, _songs[3]);

      await service().jump(3);
      expect(backend.calls.last, 'open(d, next: null)');
    });

    test('the end of the last track plays a new random order', () async {
      await onLastTrack();

      await finishTrack();

      final queue = state().queue;
      expect(queue.index, 0);
      expect(queue.shuffled, isTrue);
      expect(queue.current, isNot(_songs[3]));
      expect(titles().toList()..sort(), ['a', 'b', 'c', 'd']);
      expect(backend.calls, [
        'open(${queue.current!.title}, next: ${queue.trackAt(1).title})',
      ]);
      expect(state().playing, isTrue);
      expect(queue.unshuffledOrder, [0, 1, 2, 3]);
    });

    test('a paused player loads the new first track paused', () async {
      await onLastTrack();
      await service().pause();
      backend.calls.clear();

      await finishTrack();

      expect(backend.calls.single, endsWith(', paused)'));
      expect(state().playing, isFalse);
    });

    test('Next on the last track starts a new pass too', () async {
      await onLastTrack();

      await service().next();

      final queue = state().queue;
      expect(queue.index, 0);
      expect(queue.shuffled, isTrue);
      expect(queue.current, isNot(_songs[3]));
      expect(backend.calls.single, startsWith('open(${queue.current!.title}'));
    });

    test('every pass is a new order that starts with another track', () async {
      await onLastTrack();

      for (var pass = 0; pass < 6; pass++) {
        await service().jump(3);
        final before = state().queue.order;
        final last = state().queue.current!.title;
        await finishTrack();
        expect(state().queue.order, isNot(before));
        expect(state().queue.current!.title, isNot(last));
        expect(state().queue.index, 0);
      }
    });

    test('a "play next" mark does not outlive the pass', () async {
      await service().setRepeat(RepeatMode.allShuffled);
      await service().openTracks(_songs);
      await service().playNext([Track.fromPath('/music/e.mp3')]);

      for (var pass = 0; pass < 8; pass++) {
        await service().jump(4);
        await finishTrack();
        expect(service().upNextRun, 0, reason: 'pass $pass');
      }
    });

    test(
      'turning shuffle off after a wrap gives back the opened order',
      () async {
        await onLastTrack();
        await finishTrack();
        expect(state().queue.shuffled, isTrue);

        await service().setShuffle(false);

        expect(titles(), ['a', 'b', 'c', 'd']);
        expect(state().queue.shuffled, isFalse);
      },
    );

    test('Next on the last track keeps the order saved before', () async {
      await service().setRepeat(RepeatMode.allShuffled);
      await service().openTracks(_songs);
      await service().setShuffle(true);
      final saved = state().queue.unshuffledOrder;
      await service().jump(3);

      await service().next();

      expect(state().queue.index, 0);
      expect(state().queue.unshuffledOrder, saved);
    });

    test('a stop after the current track loads the new first paused', () async {
      await onLastTrack();
      service().setStopAfterCurrent(true);
      await pumpMicrotasks();
      backend.calls.clear();

      await finishTrack();

      expect(state().queue.index, 0);
      expect(state().playing, isFalse);
      expect(backend.calls.single, endsWith(', paused)'));
    });
  });

  group('nothing else reorders the queue', () {
    Future<void> expectNoReorder(Future<void> Function() act) async {
      await onLastTrack();
      final before = state().queue;
      await act();
      expect(state().queue.order, before.order);
      expect(state().queue.shuffled, before.shuffled);
    }

    test(
      'jump to the first track',
      () => expectNoReorder(() async {
        await service().jump(0);
        expect(state().queue.index, 0);
      }),
    );

    test('previous on the first track', () async {
      await service().setRepeat(RepeatMode.allShuffled);
      await service().openTracks(_songs);
      final before = state().queue.order;
      backend.calls.clear();

      await service().previous();

      expect(state().queue.order, before);
      expect(state().queue.index, 0);
      expect(backend.calls, isEmpty);
    });

    test(
      'opening tracks on the last one',
      () => expectNoReorder(() async {
        await service().openTracks(_songs, start: 3);
      }),
    );

    test('removing the playing last track', () async {
      await onLastTrack();

      await service().removeTrack(3);

      expect(titles(), ['a', 'b', 'c']);
      expect(state().queue.index, 0);
      expect(state().queue.shuffled, isFalse);
    });

    test('choosing the mode on the last track', () async {
      await service().openTracks(_songs, start: 3);
      backend.calls.clear();

      await service().setRepeat(RepeatMode.allShuffled);

      expect(titles(), ['a', 'b', 'c', 'd']);
      expect(state().queue.shuffled, isFalse);
      expect(backend.calls, ['setRepeat(allShuffled)', 'setNext(null)']);
    });

    test('cycling the repeat mode through all shuffled', () async {
      await service().openTracks(_songs, start: 3);

      await service().cycleRepeat();
      expect(state().queue.repeat, RepeatMode.all);
      await service().cycleRepeat();
      expect(state().queue.repeat, RepeatMode.allShuffled);
      await service().cycleRepeat();
      expect(state().queue.repeat, RepeatMode.one);
      await service().cycleRepeat();
      expect(state().queue.repeat, RepeatMode.off);

      expect(titles(), ['a', 'b', 'c', 'd']);
      expect(state().queue.shuffled, isFalse);
    });

    test('leaving the mode keeps the next track of the order', () async {
      await onLastTrack();
      await finishTrack();
      final order = state().queue.order;

      await service().setRepeat(RepeatMode.off);

      expect(state().queue.order, order);
      expect(state().queue.shuffled, isTrue);
    });
  });

  group('the engine moves on by itself', () {
    test(
      'a handed track removed on the second to last starts a pass',
      () async {
        await service().setRepeat(RepeatMode.allShuffled);
        await service().openTracks(_songs, start: 2);
        expect(backend.next, _songs[3]);
        await service().removeTrack(3);
        backend.calls.clear();

        // The engine had already moved on to the removed track.
        backend.emitAdvanced.add(_songs[3]);
        await pumpMicrotasks();

        final queue = state().queue;
        expect(queue.index, 0);
        expect(queue.shuffled, isTrue);
        expect(queue.current, isNot(_songs[2]));
        expect(titles().toList()..sort(), ['a', 'b', 'c']);
      },
    );

    test(
      'a next track handed before the mode was chosen starts a pass',
      () async {
        await service().setRepeat(RepeatMode.all);
        await service().openTracks(_songs, start: 3);
        expect(backend.next, _songs[0], reason: 'repeat all hands the first');
        final handed = backend.next!;
        await service().setRepeat(RepeatMode.allShuffled);

        backend.emitAdvanced.add(handed);
        await pumpMicrotasks();

        final queue = state().queue;
        expect(queue.current, handed);
        expect(queue.index, 0);
        expect(queue.shuffled, isTrue);
        expect(titles().toList()..sort(), ['a', 'b', 'c', 'd']);
      },
    );

    test('moving on inside a pass does not reorder', () async {
      await service().setRepeat(RepeatMode.allShuffled);
      await service().openTracks(_songs);

      backend.advance();
      await pumpMicrotasks();

      expect(titles(), ['a', 'b', 'c', 'd']);
      expect(state().queue.index, 1);
    });
  });

  test('a single track plays again and shuffle stays off', () async {
    await service().setRepeat(RepeatMode.allShuffled);
    await service().openTracks([_songs[0]]);
    backend.calls.clear();

    await finishTrack();

    expect(backend.calls, ['open(a, next: null)']);
    expect(state().playing, isTrue);
    expect(state().queue.shuffled, isFalse);
  });
}
