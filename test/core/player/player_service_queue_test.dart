import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c'), d = song('d');

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);
  List<String> titles() => [for (final t in state().queue.tracks) t.title];

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  group('moveTrack', () {
    test('requeues the next track without interrupting playback', () async {
      await service().openTracks([a, b, c, d]);
      backend.calls.clear();

      await service().moveTrack(2, 1);

      expect(titles(), ['a', 'c', 'b', 'd']);
      expect(state().queue.index, 0);
      expect(backend.calls, ['setNext(c)']);
    });

    test('dragging the playing track keeps it playing', () async {
      await service().openTracks([a, b, c, d], start: 1);
      backend.calls.clear();

      await service().moveTrack(1, 3);

      expect(titles(), ['a', 'c', 'd', 'b']);
      expect(state().queue.current, b);
      expect(state().queue.index, 3);
      expect(backend.calls, ['setNext(null)']);
    });

    test(
      'asks the engine again even when the next track is the same',
      () async {
        await service().openTracks([a, b, c, d]);
        backend.calls.clear();

        await service().moveTrack(2, 3);

        expect(backend.calls, ['setNext(b)']);
      },
    );

    test('ignores out-of-range positions', () async {
      await service().openTracks([a, b]);
      backend.calls.clear();

      await service().moveTrack(0, 5);

      expect(backend.calls, isEmpty);
    });
  });

  group('removeTrack', () {
    test('another track only requeues the next one', () async {
      await service().openTracks([a, b, c]);
      backend.calls.clear();

      await service().removeTrack(1);

      expect(titles(), ['a', 'c']);
      expect(backend.calls, ['setNext(c)']);
    });

    test('a track before the playing one keeps it playing', () async {
      await service().openTracks([a, b, c], start: 1);
      backend.calls.clear();

      await service().removeTrack(0);

      expect(state().queue.current, b);
      expect(state().queue.index, 0);
      expect(backend.calls, ['setNext(c)']);
    });

    test('the playing track plays the one that slides in', () async {
      await service().openTracks([a, b, c, d], start: 1);
      backend.calls.clear();

      await service().removeTrack(1);

      expect(backend.calls, ['open(c, next: d)']);
      expect(state().queue.current, c);
      expect(state().playing, isTrue);
    });

    test(
      'the playing track keeps playing when the engine already reported a stop',
      () async {
        await service().openTracks([a, b, c, d], start: 1);
        // mpv can turn `playing` off while idle, before it reports the end.
        backend.emitPlaying.add(false);
        backend.calls.clear();

        await service().removeTrack(1);

        expect(backend.calls, ['open(c, next: d)']);
        expect(state().playing, isTrue);
      },
    );

    test(
      'after the queue ran out the track that slides in stays paused',
      () async {
        await service().openTracks([a, b, c], start: 2);
        backend.emitCompleted.add(true);
        await service().setRepeat(RepeatMode.all);
        backend.calls.clear();

        await service().removeTrack(2);

        expect(backend.calls, ['open(a, next: b, paused)']);
        expect(state().playing, isFalse);
      },
    );

    test(
      'after giving up on a fully broken queue the next track stays paused',
      () async {
        await service().openTracks([a, b, c], start: 1);
        await service().setRepeat(RepeatMode.all);
        for (final track in [b, c, a]) {
          backend.fail(track);
          backend.emitCompleted.add(true);
        }
        expect(state().queue.current, a);
        expect(state().playing, isFalse);
        backend.calls.clear();

        await service().removeTrack(0);

        expect(backend.calls, ['open(b, next: c, paused)']);
        expect(state().playing, isFalse);
      },
    );

    test('while paused the next track loads but stays paused', () async {
      await service().openTracks([a, b, c, d], start: 1);
      await service().pause();
      backend.calls.clear();

      await service().removeTrack(1);

      expect(backend.calls, ['open(c, next: d, paused)']);
      expect(state().playing, isFalse);
      expect(state().stopped, isFalse);
    });

    test('the last track stops like the queue running out', () async {
      await service().openTracks([a, b, c], start: 2);
      backend.calls.clear();

      await service().removeTrack(2);

      expect(backend.calls, ['stop']);
      expect(titles(), ['a', 'b']);
      expect(state().queue.index, 1);
      expect(state().playing, isFalse);
      expect(state().stopped, isTrue);

      // Play starts the queue over.
      backend.calls.clear();
      await service().playPause();
      expect(backend.calls, ['open(a, next: b)']);
    });

    test('the last track with repeat all wraps to the first', () async {
      await service().openTracks([a, b, c], start: 2);
      await service().setRepeat(RepeatMode.all);
      backend.calls.clear();

      await service().removeTrack(2);

      expect(backend.calls, ['open(a, next: b)']);
      expect(state().queue.index, 0);
    });

    test('with repeat one the next track still slides in', () async {
      await service().openTracks([a, b, c], start: 1);
      await service().setRepeat(RepeatMode.one);
      backend.calls.clear();

      await service().removeTrack(1);

      expect(backend.calls, ['open(c, next: null)']);
    });

    test('the only track empties the queue and stops', () async {
      await service().openTracks([a]);
      await service().setShuffle(true);
      await service().setRepeat(RepeatMode.all);
      backend.calls.clear();

      await service().removeTrack(0);

      expect(backend.calls, ['stop']);
      expect(state().queue.isEmpty, isTrue);
      expect(state().queue.shuffled, isTrue);
      expect(state().queue.repeat, RepeatMode.all);
      expect(state().playing, isFalse);
      expect(state().position, Duration.zero);
    });

    test('a position outside the queue does nothing', () async {
      await service().openTracks([a, b]);
      backend.calls.clear();

      await service().removeTrack(2);
      await service().removeTrack(-1);

      expect(backend.calls, isEmpty);
    });

    test('a removal resets the count of broken tracks', () async {
      await service().openTracks([a, b, c]);
      await service().setRepeat(RepeatMode.all);
      backend.fail(a);
      backend.fail(b);
      await service().removeTrack(2);
      backend.calls.clear();

      backend.emitAdvanced.add(b);

      // Two failures no longer cover the two tracks left, so the engine is
      // still given a next track.
      expect(backend.calls.last, 'setNext(a)');
    });
  });

  group('clearQueue', () {
    test('keeps the playing track playing', () async {
      await service().openTracks([a, b, c], start: 1);
      backend.calls.clear();

      await service().clearQueue();

      expect(titles(), ['b']);
      expect(state().queue.index, 0);
      expect(state().playing, isTrue);
      expect(backend.calls, ['setNext(null)']);
    });

    test('with repeat all the track still loops itself', () async {
      await service().openTracks([a, b]);
      await service().setRepeat(RepeatMode.all);
      backend.calls.clear();

      await service().clearQueue();

      expect(backend.calls, ['setNext(a)']);
    });

    test('while shuffled shuffle off returns to the single track', () async {
      await service().openTracks([a, b, c, d], start: 2);
      await service().setShuffle(true);

      await service().clearQueue();
      await service().setShuffle(false);

      expect(titles(), ['c']);
    });

    test('removing the playing track afterwards empties the queue', () async {
      await service().openTracks([a, b]);
      await service().clearQueue();
      backend.calls.clear();

      await service().removeTrack(0);

      expect(backend.calls, ['stop']);
      expect(state().queue.isEmpty, isTrue);
    });
  });

  group('engine moves on after an edit', () {
    test(
      'to a next track that was dragged elsewhere keeps playing it',
      () async {
        await service().openTracks([a, b, c, d]);
        await service().moveTrack(1, 3);
        backend.calls.clear();

        // The engine took the track that was next before the drag.
        backend.emitAdvanced.add(b);

        expect(state().queue.current, b);
        expect(state().queue.index, 3);
        expect(backend.calls, ['setNext(null)']);
      },
    );

    test('to a track removed meanwhile plays the queue as it is now', () async {
      await service().openTracks([a, b, c, d]);
      await service().removeTrack(1);
      backend.calls.clear();

      backend.emitAdvanced.add(b);

      expect(backend.calls, ['open(c, next: d)']);
      expect(state().queue.current, c);
    });

    test('to a removed track at the end stops playback', () async {
      await service().openTracks([a, b]);
      await service().removeTrack(1);
      backend.calls.clear();

      backend.emitAdvanced.add(b);

      expect(backend.calls, ['stop']);
      expect(state().playing, isFalse);
      expect(state().stopped, isTrue);
    });

    test('with a file queued twice does not jump to the first copy', () async {
      final x = song('x'), y = song('y');
      await service().openTracks([a, x, a, y, a], start: 2);
      backend.calls.clear();

      // Not the entry handed over (y), so it is matched by file, after the
      // playing track rather than from the start of the queue.
      backend.emitAdvanced.add(a);

      expect(state().queue.order[state().queue.index], 4);
    });

    test('an edit queued before an open settles still requeues', () async {
      await service().openTracks([a, b, c]);
      await service().moveTrack(1, 2);

      expect(backend.calls, ['open(a, next: b)', 'setNext(c)']);
    });
  });
}
