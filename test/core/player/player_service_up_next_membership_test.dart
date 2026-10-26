import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c'), d = song('d');
final x = song('x'), y = song('y'), z = song('z');

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);
  List<String> titles() => [for (final t in state().queue.tracks) t.title];
  int run() => service().upNextRun;

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  group('moving inside the play next block', () {
    setUp(() async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y, z]);
      expect(titles(), ['a', 'x', 'y', 'z', 'b', 'c']);
    });

    test('reordering the block keeps all of it marked', () async {
      await service().moveTrack(1, 3);

      expect(titles(), ['a', 'y', 'z', 'x', 'b', 'c']);
      expect(run(), 3);
    });

    test(
      'dropping a block track behind the next plain track unmarks it',
      () async {
        await service().moveTrack(1, 4);

        expect(titles(), ['a', 'y', 'z', 'b', 'x', 'c']);
        expect(run(), 2);
        // It lost its mark, so bringing it back does not join the block.
        await service().moveTrack(4, 1);
        expect(titles(), ['a', 'x', 'y', 'z', 'b', 'c']);
        expect(run(), 0);
      },
    );

    test(
      'dropping a block track behind the last block track keeps it',
      () async {
        await service().moveTrack(1, 3);
        await service().moveTrack(3, 1);

        expect(titles(), ['a', 'x', 'y', 'z', 'b', 'c']);
        expect(run(), 3);
      },
    );

    test('dragging a block track out unmarks it', () async {
      await service().moveTrack(2, 5);

      expect(titles(), ['a', 'x', 'z', 'b', 'c', 'y']);
      expect(run(), 2);
      await service().moveTrack(5, 1);
      // It does not regain the mark, so the block now starts with a plain one.
      expect(titles(), ['a', 'y', 'x', 'z', 'b', 'c']);
      expect(run(), 0);
    });

    test('a plain track dropped in the block does not join it', () async {
      await service().moveTrack(5, 2);

      expect(titles(), ['a', 'x', 'c', 'y', 'z', 'b']);
      expect(run(), 1);
    });
  });

  group('marks that are not next to the current track', () {
    test('Previous leaves the later marks outside the run', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().next();
      expect(titles(), ['a', 'x', 'y', 'b', 'c']);
      expect(run(), 1);

      await service().previous();

      expect(state().queue.index, 0);
      expect(run(), 0);
    });

    test('jumping past the block leaves it outside the run', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);

      await service().jump(3);

      expect(run(), 0);
    });

    test(
      'unshuffling leaves a mark behind the current track outside',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            audioBackendProvider.overrideWithValue(backend),
            playerServiceProvider.overrideWith(
              () => PlayerService(random: Random(3)),
            ),
          ],
        )..listen(playerServiceProvider, (_, _) {});
        await service().openTracks([a, b, c, d]);
        await service().setShuffle(true);
        await service().playNext([x]);
        await service().jump(3);
        await service().playNext([y]);
        expect(run(), 1);

        await service().setShuffle(false);

        final queue = state().queue;
        expect(queue.order.length, 6);
        expect(queue.trackAt(queue.index + 1), y);
        expect(run(), 1);
        // x is still marked but is not next to the current track: not counted.
        expect(titles().indexOf('x'), isNot(queue.index + 2));
      },
    );

    test('a track dropped next to a stray mark never gains one', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().next();
      await service().previous();
      expect(titles(), ['a', 'x', 'y', 'b', 'c']);

      await service().moveTrack(2, 1);

      expect(titles(), ['a', 'y', 'x', 'b', 'c']);
      expect(run(), 0);
    });
  });

  group('moveToPlayNext', () {
    test('a track from far below lands behind the block', () async {
      await service().openTracks([a, b, c, d]);
      await service().playNext([x]);
      backend.calls.clear();

      await service().moveToPlayNext(4);

      expect(titles(), ['a', 'x', 'd', 'b', 'c']);
      expect(run(), 2);
      expect(backend.calls, ['setNext(x)']);
      await service().playNext([y]);
      expect(titles(), ['a', 'x', 'd', 'y', 'b', 'c']);
    });

    test('a played track moves without interrupting the playing one', () async {
      await service().openTracks([a, b, c, d]);
      await service().jump(2);
      backend.calls.clear();

      await service().moveToPlayNext(0);

      expect(titles(), ['b', 'c', 'a', 'd']);
      expect(state().queue.current, c);
      expect(state().queue.index, 1);
      expect(run(), 1);
      expect(backend.calls.where((call) => call.startsWith('open')), isEmpty);
      expect(backend.next, a);
    });

    test('the playing track and block tracks are left alone', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      final before = state().queue;
      backend.calls.clear();

      await service().moveToPlayNext(0);
      await service().moveToPlayNext(1);
      await service().moveToPlayNext(2);
      await service().moveToPlayNext(-1);
      await service().moveToPlayNext(99);

      expect(identical(state().queue, before), isTrue);
      expect(backend.calls, isEmpty);
    });

    test('the track already at the target is only marked', () async {
      await service().openTracks([a, b, c]);
      final before = state().queue;
      backend.calls.clear();

      await service().moveToPlayNext(1);

      expect(identical(state().queue, before), isFalse);
      expect(titles(), ['a', 'b', 'c']);
      expect(run(), 1);
      expect(backend.calls, isEmpty);
    });

    test('after the queue ended the moved track is loaded paused', () async {
      await service().openTracks([a, b, c]);
      await service().jump(2);
      await service().removeTrack(2);
      expect(state().stopped, isTrue);
      backend.calls.clear();

      await service().moveToPlayNext(0);

      expect(titles(), ['b', 'a']);
      expect(state().queue.current, a);
      expect(backend.calls, ['open(a, next: null, paused)']);
      await service().play();
      expect(state().playing, isTrue);
      expect(state().queue.current, a);
    });

    test('an ended queue plays the marked track already in place', () async {
      await service().openTracks([a, b, c]);
      await service().jump(2);
      await service().removeTrack(2);
      await service().moveTrack(0, 1);
      expect(titles(), ['b', 'a']);
      expect(state().queue.current, b);
      backend.calls.clear();

      await service().moveToPlayNext(1);

      expect(state().queue.current, a);
      expect(backend.calls, ['open(a, next: null, paused)']);
    });
  });

  test('moving inside a block of 10k in a queue of 50k is fast', () async {
    final all = [for (var i = 0; i < 40000; i++) song('t$i')];
    final next = [for (var i = 0; i < 10000; i++) song('n$i')];
    await service().openTracks(all);
    await service().playNext(next);
    expect(run(), 10000);

    final watch = Stopwatch()..start();
    await service().moveTrack(1, 9000);
    watch.stop();

    expect(watch.elapsedMilliseconds, lessThan(50));
    expect(run(), 10000);
  });
}
