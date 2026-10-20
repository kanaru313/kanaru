import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_error.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

final songs = [
  for (final name in ['a', 'b', 'c', 'd']) Track.fromPath('/music/$name.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  int index() => container.read(playerServiceProvider).queue.index;
  bool playing() => container.read(playerServiceProvider).playing;

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    // Keeps the notifier alive and subscribed for the whole test.
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('opening plays the start track with the next one queued', () async {
    await service().openTracks(songs, start: 1);

    expect(backend.calls, ['open(b, next: c)']);
    final state = container.read(playerServiceProvider);
    expect(state.queue.current, songs[1]);
    expect(state.playing, isTrue);
  });

  test('opening nothing keeps the queue', () async {
    await service().openTracks(const []);
    expect(backend.calls, isEmpty);
  });

  test('the last track queues nothing with repeat off', () async {
    await service().openTracks(songs, start: 3);
    expect(backend.calls, ['open(d, next: null)']);
  });

  group('previous', () {
    test('goes back a track however long this one played', () async {
      await service().openTracks(songs, start: 2);
      backend.emitPosition.add(const Duration(seconds: 40));

      await service().previous();

      expect(backend.calls.last, 'open(b, next: c)');
      expect(index(), 1);
    });

    test('does nothing on the first track', () async {
      await service().openTracks(songs);
      await service().previous();
      expect(backend.calls, ['open(a, next: b)']);
    });

    test('wraps to the last track with repeat all', () async {
      await service().openTracks(songs);
      await service().cycleRepeat();
      await service().previous();
      expect(backend.calls.last, 'open(d, next: a)');
    });
  });

  test('next stops at the end with repeat off', () async {
    await service().openTracks(songs, start: 3);
    await service().next();
    expect(backend.calls, ['open(d, next: null)']);
  });

  test('repeat all queues the first track after the last', () async {
    await service().openTracks(songs, start: 3);
    await service().cycleRepeat();
    expect(backend.calls.skip(1), ['setRepeat(all)', 'setNext(a)']);
  });

  test('next with repeat one moves on', () async {
    await service().openTracks(songs);
    await service().cycleRepeat();
    await service().cycleRepeat();
    backend.calls.clear();

    await service().next();

    expect(backend.calls, ['open(b, next: c)']);
    expect(container.read(playerServiceProvider).queue.repeat, RepeatMode.one);
  });

  test('play/pause toggles the engine', () async {
    await service().openTracks(songs);
    await service().playPause();
    await service().playPause();
    expect(backend.calls.skip(1), ['pause', 'play']);
  });

  test('shuffle only changes the queued next track', () async {
    await service().openTracks(songs, start: 2);
    await service().toggleShuffle();

    final queue = container.read(playerServiceProvider).queue;
    expect(queue.current, songs[2]);
    expect(backend.calls, [
      'open(c, next: d)',
      'setNext(${queue.tracks[1].title})',
    ]);

    await service().toggleShuffle();
    expect(backend.calls.last, 'setNext(d)');
    expect(index(), 2);
  });

  test(
    'engine advancing moves the queue and queues the following track',
    () async {
      await service().openTracks(songs);
      backend.emitPosition.add(const Duration(seconds: 30));

      backend.advance();

      final state = container.read(playerServiceProvider);
      expect(state.queue.current, songs[1]);
      expect(state.position, Duration.zero);
      expect(backend.calls.last, 'setNext(c)');
    },
  );

  test('an advance to a track queued before a shuffle lands on it', () async {
    await service().openTracks(songs);
    final queued = backend.next!;
    // The engine moves on before the reshuffled next track reaches it.
    await service().toggleShuffle();
    backend.emitAdvanced.add(queued);

    expect(container.read(playerServiceProvider).queue.current, queued);
  });

  test('stops after the last track; play starts the queue over', () async {
    await service().openTracks(songs, start: 3);
    backend.emitCompleted.add(true);
    expect(playing(), isFalse);

    await service().playPause();
    expect(backend.calls.last, 'open(a, next: b)');
    expect(index(), 0);
  });

  group('broken tracks', () {
    test('a failed track is reported without skipping by itself', () async {
      final errors = <PlaybackError>[];
      service().errors.listen(errors.add);
      await service().openTracks(songs);

      backend.fail(songs[0]);
      // The engine moves on to the queued next track by itself.
      backend.advance();
      await Future<void>.delayed(Duration.zero);

      expect(errors.map((e) => e.track), [songs[0]]);
      expect(backend.calls, ['open(a, next: b)', 'setNext(c)']);
    });

    test('a broken track that stops the engine is skipped', () async {
      await service().openTracks(songs, start: 1);
      backend.fail(songs[1]);
      backend.emitCompleted.add(true);

      expect(index(), 2);
      expect(backend.calls.last, 'open(c, next: d)');
    });

    test('the engine running out of tracks goes on with the queue', () async {
      await service().openTracks(songs);
      backend.emitCompleted.add(true);

      expect(index(), 1);
      expect(backend.calls.last, 'open(b, next: c)');
    });

    test('gives up when the engine skips every broken track itself', () async {
      final three = songs.take(3).toList();
      await service().openTracks(three);
      await service().cycleRepeat(); // repeat all: there is always a next
      for (final track in three) {
        backend.fail(track);
        backend.advance();
      }

      // Back on the first track after a full round of failures.
      expect(index(), 0);
      expect(backend.calls.last, 'setNext(null)');

      backend.fail(three[0]);
      backend.emitCompleted.add(true);
      expect(playing(), isFalse);
      expect(backend.calls.where((c) => c.startsWith('open')), hasLength(1));
    });

    test('gives up when every track is broken', () async {
      final two = songs.take(2).toList();
      await service().openTracks(two);
      await service().cycleRepeat();
      for (var i = 0; i < 4; i++) {
        backend.fail(two[i % 2]);
        backend.emitCompleted.add(true);
      }

      expect(playing(), isFalse);
      expect(backend.calls.where((c) => c.startsWith('open')), hasLength(2));
    });

    test('a new queue gets a fresh count of failures', () async {
      final three = songs.take(3).toList();
      await service().openTracks(three);
      for (final track in three) {
        backend.fail(track);
        backend.emitCompleted.add(true);
      }
      expect(playing(), isFalse);

      await service().openTracks(three);
      backend.fail(three[0]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(b, next: c)');
    });

    test('a broken track loaded paused is skipped without playing', () async {
      final three = songs.take(3).toList();
      await service().openTracks(three);
      await service().pause();
      await service().removeTrack(0);
      expect(backend.calls.last, 'open(b, next: c, paused)');

      backend.fail(three[1]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(c, next: null, paused)');
      expect(playing(), isFalse);
    });

    test('play after a paused load brings back auto-skip', () async {
      await service().openTracks(songs);
      await service().pause();
      await service().removeTrack(0);
      expect(backend.calls.last, 'open(b, next: c, paused)');

      await service().play();
      backend.fail(songs[1]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(c, next: d)');
      expect(playing(), isTrue);
    });

    test(
      'a paused load that advances to a removed track stays paused',
      () async {
        await service().openTracks(songs);
        await service().pause();
        await service().removeTrack(0);
        expect(backend.calls.last, 'open(b, next: c, paused)');
        await service().removeTrack(1); // c, already handed to the engine

        backend.fail(songs[1]);
        // The engine had c queued and moves on to it anyway.
        backend.emitAdvanced.add(songs[2]);
        await Future<void>.delayed(Duration.zero);

        expect(backend.calls.last, 'open(d, next: null, paused)');
        expect(playing(), isFalse);
      },
    );

    test('pausing during a load keeps the next track paused', () async {
      await service().openTracks(songs);
      await service().pause();

      backend.fail(songs[0]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(b, next: c, paused)');
      expect(playing(), isFalse);
    });

    test('pause after the engine paused on its own is kept', () async {
      await service().openTracks(songs);
      // mpv reports the pause of a failing load before it stops.
      backend.emitPlaying.add(false);
      await service().pause();

      backend.fail(songs[0]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(b, next: c, paused)');
    });

    test('a broken track keeps playing when it was playing', () async {
      await service().openTracks(songs);

      backend.fail(songs[0]);
      backend.emitCompleted.add(true);

      expect(backend.calls.last, 'open(b, next: c)');
      expect(playing(), isTrue);
    });

    test('every missing track with repeat off stops on the last one', () async {
      final three = songs.take(3).toList();
      await service().openTracks(three);
      for (final track in three) {
        backend.fail(track);
        backend.emitCompleted.add(true);
      }

      expect(backend.calls.where((c) => c.startsWith('open')), hasLength(3));
      final state = container.read(playerServiceProvider);
      expect(state.stopped, isTrue);
      expect(state.playing, isFalse);
      expect(state.queue.index, 2);
    });
  });

  test('seeking into the finished last track resumes it on play', () async {
    await service().openTracks(songs, start: 3);
    backend.emitDuration.add(const Duration(seconds: 100));
    backend.emitCompleted.add(true);

    await service().seek(const Duration(seconds: 40));
    await service().playPause();

    expect(backend.calls.last, 'play');
    expect(index(), 3);
  });

  test('mute remembers the volume and unmute restores it', () async {
    await service().setVolume(60);
    await service().toggleMute();

    var state = container.read(playerServiceProvider);
    expect(state.muted, isTrue);
    expect(state.volume, 0);

    await service().toggleMute();
    state = container.read(playerServiceProvider);
    expect(state.muted, isFalse);
    expect(state.volume, 60);
    expect(backend.calls, [
      'setVolume(60.0)',
      'setVolume(0.0)',
      'setVolume(60.0)',
    ]);
  });

  test('seekBy stays inside the track', () async {
    await service().openTracks(songs);
    backend.emitDuration.add(const Duration(seconds: 100));
    backend.emitPosition.add(const Duration(seconds: 98));

    await service().seekBy(const Duration(seconds: 5));
    expect(backend.calls.last, 'seek(${const Duration(seconds: 100)})');

    backend.emitPosition.add(const Duration(seconds: 2));
    await service().seekBy(const Duration(seconds: -5));
    expect(backend.calls.last, 'seek(${Duration.zero})');
  });

  group('absolute commands', () {
    test('setShuffle and setRepeat ignore the value already set', () async {
      await service().openTracks(songs, start: 2);
      backend.calls.clear();

      await service().setShuffle(false);
      await service().setRepeat(RepeatMode.off);
      expect(backend.calls, isEmpty);

      await service().setShuffle(true);
      final order = container.read(playerServiceProvider).queue.order;
      await service().setShuffle(true);
      expect(container.read(playerServiceProvider).queue.order, order);
      expect(backend.calls, hasLength(1));

      await service().setRepeat(RepeatMode.one);
      await service().setRepeat(RepeatMode.one);
      expect(backend.calls.where((c) => c.startsWith('setRepeat')), [
        'setRepeat(one)',
      ]);
    });

    test('setRepeat jumps straight to a mode', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);
      expect(
        container.read(playerServiceProvider).queue.repeat,
        RepeatMode.one,
      );
    });

    test('play and pause do not flip the state', () async {
      await service().openTracks(songs);
      backend.calls.clear();

      await service().play(); // already playing
      expect(backend.calls, isEmpty);

      await service().pause();
      await service().pause();
      expect(backend.calls, ['pause']);
      expect(playing(), isFalse);

      await service().play();
      await service().play();
      expect(backend.calls, ['pause', 'play']);
      expect(playing(), isTrue);
    });
  });

  group('stop', () {
    PlayerState current() => container.read(playerServiceProvider);

    test('rewinds, keeps the queue, and play restarts the track', () async {
      await service().openTracks(songs, start: 1);
      backend.emitPosition.add(const Duration(seconds: 30));
      backend.calls.clear();

      await service().stop();

      expect(current().playing, isFalse);
      expect(current().stopped, isTrue);
      expect(current().position, Duration.zero);
      expect(current().queue.current, songs[1]);
      expect(backend.calls, ['pause', 'seek(${Duration.zero})']);

      await service().play();
      expect(backend.calls.last, 'play');
      expect(current().playing, isTrue);
      expect(current().stopped, isFalse);
      expect(current().queue.current, songs[1]);
    });

    test('does nothing without a queue', () async {
      await service().stop();
      expect(backend.calls, isEmpty);
      expect(current().stopped, isFalse);
    });

    test('stays stopped after next immediately followed by stop', () async {
      await service().openTracks(songs);
      backend.calls.clear();

      final moving = service().next();
      final stopping = service().stop();
      await Future.wait([moving, stopping]);

      expect(backend.calls, [
        'open(b, next: c)',
        'pause',
        'seek(${Duration.zero})',
      ]);
      expect(current().playing, isFalse);
      expect(current().stopped, isTrue);
      expect(current().queue.current, songs[1]);
    });

    test('the queue running out counts as stopped', () async {
      await service().openTracks(songs, start: 3);
      backend.emitCompleted.add(true);
      expect(current().stopped, isTrue);
    });

    test('jumping, seeking and opening clear it', () async {
      await service().openTracks(songs);
      for (final resume in <Future<void> Function()>[
        () => service().jump(2),
        () => service().seek(const Duration(seconds: 5)),
        () => service().openTracks(songs),
      ]) {
        await service().stop();
        expect(current().stopped, isTrue);
        await resume();
        expect(current().stopped, isFalse);
      }
    });
  });

  group('seeked', () {
    late List<Duration> seeks;
    setUp(() {
      seeks = [];
    });

    test('fires once per seek, whatever the engine reports', () async {
      await service().openTracks(songs);
      service().seeked.listen(seeks.add);
      backend.emitPosition.add(const Duration(seconds: 50));

      await service().seek(const Duration(seconds: 10));
      // Stale tick from before the seek, then the real one.
      backend.emitPosition.add(const Duration(seconds: 50));
      backend.emitPosition.add(const Duration(seconds: 10));
      backend.emitPosition.add(const Duration(seconds: 11));
      await Future<void>.delayed(Duration.zero);

      expect(seeks, [const Duration(seconds: 10)]);
    });

    test('seekBy fires once too', () async {
      await service().openTracks(songs);
      service().seeked.listen(seeks.add);
      backend.emitPosition.add(const Duration(seconds: 20));

      await service().seekBy(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);

      expect(seeks, [const Duration(seconds: 25)]);
    });

    test('repeat one starting the track over fires seeked(0)', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);
      service().seeked.listen(seeks.add);

      backend.emitDuration.add(const Duration(seconds: 180));
      await Future<void>.delayed(Duration.zero);
      backend.emitPosition.add(const Duration(seconds: 179));
      backend.emitPosition.add(const Duration(seconds: 180));
      backend.emitPosition.add(Duration.zero);
      backend.emitPosition.add(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(seeks, [Duration.zero]);
    });

    test('plain progress and other repeat modes stay silent', () async {
      await service().openTracks(songs);
      service().seeked.listen(seeks.add);

      backend.emitPosition.add(const Duration(seconds: 180));
      backend.emitPosition.add(Duration.zero); // repeat off: not a loop
      backend.emitPosition.add(const Duration(seconds: 1));
      await service().setRepeat(RepeatMode.one);
      backend.emitPosition.add(const Duration(seconds: 2));
      backend.emitPosition.add(const Duration(seconds: 3));
      await Future<void>.delayed(Duration.zero);

      expect(seeks, isEmpty);
    });

    test('a new track starting at zero is not a loop', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);
      service().seeked.listen(seeks.add);

      backend.emitPosition.add(const Duration(seconds: 180));
      await service().next();
      backend.emitPosition.add(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(seeks, isEmpty);
    });

    group('stale ticks under repeat one', () {
      setUp(() async {
        await service().openTracks(songs);
        await service().setRepeat(RepeatMode.one);
        service().seeked.listen(seeks.add);
        backend.emitDuration.add(const Duration(seconds: 180));
        await Future<void>.delayed(Duration.zero);
      });

      test('after next', () async {
        backend.emitPosition.add(const Duration(seconds: 179));
        await service().next();
        backend.emitPosition.add(const Duration(seconds: 179)); // stale
        backend.emitDuration.add(const Duration(seconds: 200));
        backend.emitPosition.add(Duration.zero);
        backend.emitPosition.add(const Duration(seconds: 1));
        await Future<void>.delayed(Duration.zero);

        expect(seeks, isEmpty);
      });

      test('after seeking near the start', () async {
        backend.emitPosition.add(const Duration(seconds: 100));
        await service().seek(const Duration(seconds: 1));
        backend.emitPosition.add(const Duration(seconds: 100)); // stale
        backend.emitPosition.add(const Duration(seconds: 1));
        await Future<void>.delayed(Duration.zero);

        // Only the seek itself.
        expect(seeks, [const Duration(seconds: 1)]);
      });

      test('after stop', () async {
        backend.emitPosition.add(const Duration(seconds: 100));
        await service().stop();
        backend.emitPosition.add(const Duration(seconds: 100)); // stale
        backend.emitPosition.add(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(seeks, isEmpty);
      });
    });
  });
}
