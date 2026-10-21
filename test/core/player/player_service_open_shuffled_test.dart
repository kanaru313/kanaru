import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

void main() {
  final tracks = [for (final n in 'abcdefgh'.split('')) song(n)];
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);

  ProviderContainer makeContainer(int seed) => ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(backend),
      playerServiceProvider.overrideWith(
        () => PlayerService(random: Random(seed)),
      ),
    ],
  )..listen(playerServiceProvider, (_, _) {});

  setUp(() {
    backend = FakeAudioBackend();
    container = makeContainer(7);
  });
  tearDown(() => container.dispose());

  test('queues every track shuffled and plays the chosen one first', () async {
    await service().openShuffled(tracks);

    final queue = state().queue;
    expect(queue.shuffled, isTrue);
    expect(queue.original, tracks);
    expect(queue.order, hasLength(tracks.length));
    expect(queue.order.toSet(), {for (var i = 0; i < tracks.length; i++) i});
    expect(queue.index, 0, reason: 'the start track leads the play order');
    expect(state().playing, isTrue);
    expect(backend.calls.any((c) => c.startsWith('open(')), isTrue);
  });

  test('the start comes from the seeded random', () async {
    final expected = Random(7).nextInt(tracks.length);

    await service().openShuffled(tracks);

    expect(state().queue.current, tracks[expected]);

    final other = makeContainer(7);
    addTearDown(other.dispose);
    await other.read(playerServiceProvider.notifier).openShuffled(tracks);
    expect(other.read(playerServiceProvider).queue.current, tracks[expected]);
  });

  test('turning shuffle off restores the given order', () async {
    await service().openShuffled(tracks);
    final playing = state().queue.current;

    await service().setShuffle(false);

    expect([for (final t in state().queue.tracks) t], tracks);
    expect(state().queue.current, playing);
  });

  test('keeps repeat', () async {
    await service().openTracks(tracks.sublist(0, 3));
    await service().setRepeat(RepeatMode.all);

    await service().openShuffled(tracks);

    expect(state().queue.repeat, RepeatMode.all);
    expect(state().queue.original, tracks);
  });

  test('drops the places held by tracks queued to play next', () async {
    // Queueing x holds entry 3 (the first free number) as "play next". Take
    // a seed whose play order has entry 3 right after the start track: were
    // the held place kept, it would count as a queued track there.
    const maxSeeds = 1000;
    var seed = 0;
    while (true) {
      if (seed >= maxSeeds) {
        fail('no seed below $maxSeeds puts entry 3 right after the start');
      }
      final probe = makeContainer(seed);
      await probe.read(playerServiceProvider.notifier).openShuffled(tracks);
      final queue = probe.read(playerServiceProvider).queue;
      final hit = queue.order[queue.index + 1] == 3;
      probe.dispose();
      if (hit) break;
      seed++;
    }
    container.dispose();
    container = makeContainer(seed);
    await service().openTracks(tracks.sublist(0, 3));
    await service().playNext([song('x')]);

    await service().openShuffled(tracks);
    final y = song('y');
    await service().playNext([y]);

    final queue = state().queue;
    expect(queue.trackAt(queue.index + 1), y);
  });

  test('an empty list does nothing', () async {
    await service().openTracks(tracks);
    backend.calls.clear();

    await service().openShuffled(const []);

    expect(state().queue.original, tracks);
    expect(backend.calls, isEmpty);
  });
}
