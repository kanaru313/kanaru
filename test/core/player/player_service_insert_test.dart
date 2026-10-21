import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c');
final x = song('x'), y = song('y'), z = song('z');

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

  group('playNext', () {
    test(
      'goes right after the playing track without interrupting it',
      () async {
        await service().openTracks([a, b, c]);
        backend.calls.clear();

        await service().playNext([x, y]);

        expect(titles(), ['a', 'x', 'y', 'b', 'c']);
        expect(state().queue.current, a);
        expect(backend.calls, ['setNext(x)']);
      },
    );

    test('several in a row play in the order they were picked', () async {
      await service().openTracks([a, b, c]);

      await service().playNext([x]);
      await service().playNext([y]);
      await service().playNext([z]);

      expect(titles(), ['a', 'x', 'y', 'z', 'b', 'c']);
    });

    test('a track that started playing no longer holds its place', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x]);
      await service().playNext([y]);

      backend.advance();
      expect(state().queue.current, x);
      await service().playNext([z]);

      expect(titles(), ['a', 'x', 'y', 'z', 'b', 'c']);

      await service().next();
      await service().next();
      expect(state().queue.current, z);
      await service().playNext([c]);
      expect(state().queue.trackAt(state().queue.index + 1), c);
    });

    test('a new queue forgets the earlier picks', () async {
      await service().openTracks([a, b]);
      await service().playNext([x]);

      await service().openTracks([a, b, c]);
      await service().playNext([y]);

      expect(titles(), ['a', 'y', 'b', 'c']);
    });

    test('with nothing queued, plays the tracks', () async {
      await service().playNext([x, y]);

      expect(titles(), ['x', 'y']);
      expect(state().playing, isTrue);
      expect(backend.calls, ['open(x, next: y)']);
    });

    test('while shuffled plays next and stays after it unshuffled', () async {
      await service().setShuffle(true);
      await service().openTracks([a, b, c], start: 1);
      await service().playNext([x]);

      expect(state().queue.trackAt(state().queue.index + 1), x);

      await service().setShuffle(false);
      expect(titles(), ['a', 'b', 'x', 'c']);
      expect(state().queue.current, b);
    });

    test('does nothing with no tracks', () async {
      await service().openTracks([a, b]);
      backend.calls.clear();

      await service().playNext(const []);
      await service().addToQueue(const []);

      expect(titles(), ['a', 'b']);
      expect(backend.calls, isEmpty);
    });
  });

  group('addToQueue', () {
    test('appends without interrupting the playing track', () async {
      await service().openTracks([a, b]);
      backend.calls.clear();

      await service().addToQueue([x, y]);

      expect(titles(), ['a', 'b', 'x', 'y']);
      expect(state().queue.current, a);
      expect(backend.calls, ['setNext(b)']);
    });

    test('on the last track becomes the next one', () async {
      await service().openTracks([a, b], start: 1);
      backend.calls.clear();

      await service().addToQueue([x]);

      expect(backend.calls, ['setNext(x)']);
      backend.advance();
      expect(state().queue.current, x);
    });

    test('with repeat all the added tracks come before wrapping', () async {
      await service().cycleRepeat();
      expect(state().queue.repeat, RepeatMode.all);
      await service().openTracks([a, b], start: 1);

      await service().addToQueue([x]);

      expect(backend.next, x);
    });

    test('with nothing queued, plays the tracks', () async {
      await service().addToQueue([x]);

      expect(titles(), ['x']);
      expect(state().playing, isTrue);
    });

    test(
      'after the queue ran out, loads the first added track paused',
      () async {
        await service().openTracks([a, b], start: 1);
        backend.emitCompleted.add(true);
        expect(state().stopped, isTrue);
        backend.calls.clear();

        await service().addToQueue([x, y]);

        expect(state().queue.current, x);
        expect(state().playing, isFalse);
        expect(state().stopped, isFalse);
        expect(backend.calls, ['open(x, next: y, paused)']);

        await service().playPause();
        expect(state().playing, isTrue);
        expect(state().queue.current, x);
      },
    );

    test('play next after the queue ran out loads that track paused', () async {
      await service().openTracks([a, b], start: 1);
      backend.emitCompleted.add(true);
      backend.calls.clear();

      await service().playNext([x]);

      expect(titles(), ['a', 'b', 'x']);
      expect(state().queue.current, x);
      expect(backend.calls, ['open(x, next: null, paused)']);
    });

    test('a queue that ran out without additions still starts over', () async {
      await service().openTracks([a, b], start: 1);
      backend.emitCompleted.add(true);
      backend.calls.clear();

      await service().playPause();

      expect(state().queue.current, a);
    });
  });

  group('up next run', () {
    test('removing, dragging or clearing releases the held place', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x]);
      await service().playNext([y]);
      expect(titles(), ['a', 'x', 'y', 'b', 'c']);

      await service().removeTrack(1);
      await service().playNext([z]);
      expect(titles(), ['a', 'y', 'z', 'b', 'c']);

      await service().moveTrack(1, 4);
      await service().playNext([x]);
      expect(titles(), ['a', 'z', 'x', 'b', 'c', 'y']);

      await service().clearQueue();
      await service().playNext([b]);
      await service().playNext([c]);
      expect(titles(), ['a', 'b', 'c']);
    });

    test(
      'shuffling keeps the picked tracks right after the current one',
      () async {
        await service().openTracks([a, b, c, x, y]);
        await service().playNext([z]);
        await service().playNext([b]);

        await service().setShuffle(true);

        final queue = state().queue;
        expect(queue.current, a);
        expect(queue.trackAt(1), z);
        expect(queue.trackAt(2), b);
        expect(backend.next, z);
      },
    );

    test('an empty queue plays in the order given, shuffle stays on', () async {
      await service().setShuffle(true);

      await service().addToQueue([x, y, z, a, b, c]);

      expect(titles(), ['x', 'y', 'z', 'a', 'b', 'c']);
      expect(state().queue.shuffled, isTrue);
      expect(state().queue.current, x);
      expect(backend.calls, ['open(x, next: y)']);

      await service().setShuffle(false);
      expect(titles(), ['x', 'y', 'z', 'a', 'b', 'c']);
    });

    test('an emptied shuffled queue starts in the order given', () async {
      await service().openTracks([a]);
      await service().setShuffle(true);
      await service().removeTrack(0);
      expect(state().queue.isEmpty, isTrue);

      await service().playNext([x, y]);

      expect(titles(), ['x', 'y']);
      expect(state().queue.shuffled, isTrue);
    });
  });

  group('engine races', () {
    test(
      'the engine moving to the old next track keeps the picked ones next',
      () async {
        await service().openTracks([a, b, c]);
        await service().playNext([x]);
        await service().playNext([y]);

        // The engine had already started b when it learned about x.
        backend.emitAdvanced.add(b);

        expect(titles(), ['a', 'b', 'x', 'y', 'c']);
        expect(state().queue.current, b);
        expect(backend.next, x);

        backend.advance();
        expect(state().queue.current, x);
        backend.advance();
        expect(state().queue.current, y);
      },
    );

    test(
      'the engine moving to a track not behind picked ones is followed',
      () async {
        await service().openTracks([a, b, c]);
        await service().addToQueue([x]);

        backend.emitAdvanced.add(b);

        expect(titles(), ['a', 'b', 'c', 'x']);
        expect(state().queue.current, b);
      },
    );

    test(
      'a next track dropped while the engine loads is handed over after',
      () async {
        backend.openGate = Completer<void>();
        final opening = service().openTracks([a, b]);

        await service().playNext([x]);
        expect(backend.calls, ['open(a, next: b)', 'setNext(x) dropped']);
        expect(backend.next, b);

        backend.openGate!.complete();
        await opening;

        expect(backend.calls.last, 'setNext(x)');
        expect(backend.next, x);
        expect(titles(), ['a', 'x', 'b']);
      },
    );

    test('an open that finishes unchanged hands nothing over again', () async {
      backend.openGate = Completer<void>();
      final opening = service().openTracks([a, b]);
      backend.openGate!.complete();
      await opening;

      expect(backend.calls, ['open(a, next: b)']);
    });
  });
}
