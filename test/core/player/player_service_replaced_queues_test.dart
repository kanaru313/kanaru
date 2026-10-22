import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

void main() {
  final albumA = [for (final n in 'abcd'.split('')) song(n)];
  final albumB = [for (final n in 'wxyz'.split('')) song(n)];
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late List<PlayQueue> replaced;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  PlayerState state() => container.read(playerServiceProvider);

  // Broadcast events reach listeners in a later microtask.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(3)),
        ),
      ],
    )..listen(playerServiceProvider, (_, _) {});
    replaced = [];
  });
  tearDown(() => container.dispose());

  test('opening over an empty queue announces nothing', () async {
    service().replacedQueues.listen(replaced.add);

    await service().openTracks(albumA);
    await settle();

    expect(replaced, isEmpty);
  });

  test('opening over a queue announces the old queue once', () async {
    await service().openTracks(albumA, start: 2);
    final old = state().queue;
    service().replacedQueues.listen(replaced.add);

    await service().openTracks(albumB);
    await settle();

    expect(replaced, hasLength(1));
    expect(replaced.single, same(old));
    expect(replaced.single.original, albumA);
    expect(replaced.single.order, old.order);
    expect(replaced.single.index, 2);
  });

  test('opening shuffled over a queue announces the old queue', () async {
    await service().openTracks(albumA, start: 1);
    final old = state().queue;
    service().replacedQueues.listen(replaced.add);

    await service().openShuffled(albumB);
    await settle();

    expect(replaced, [same(old)]);
  });

  test('a listener sees the new queue already in place', () async {
    await service().openTracks(albumA);
    final seen = <List<Track>>[];
    service().replacedQueues.listen((_) => seen.add(state().queue.original));

    await service().openTracks(albumB);
    await settle();

    expect(seen, [albumB]);
  });

  test('changes that keep the queue announce nothing', () async {
    await service().openTracks(albumA);
    service().replacedQueues.listen(replaced.add);

    await service().playNext([song('n')]);
    await service().addToQueue([song('q')]);
    await service().next();
    backend.emitAdvanced.add(state().queue.tracks.elementAt(2));
    await service().toggleShuffle();
    await service().setRepeat(RepeatMode.all);
    await service().moveTrack(0, 1);
    await service().removeTrack(state().queue.order.length - 1);
    await service().clearQueue();
    await settle();

    expect(replaced, isEmpty);
  });

  test('a rebuilt service closes the old stream and uses a new one', () async {
    container.dispose();
    final engines = [FakeAudioBackend(), FakeAudioBackend()];
    var built = 0;
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWith((ref) => engines[built++]),
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(3)),
        ),
      ],
    )..listen(playerServiceProvider, (_, _) {});
    var oldDone = false;
    service().replacedQueues.listen(
      replaced.add,
      onDone: () {
        oldDone = true;
      },
    );

    container.invalidate(audioBackendProvider);
    state();
    await settle();
    expect(oldDone, isTrue);

    final fresh = <PlayQueue>[];
    service().replacedQueues.listen(fresh.add);
    await service().openTracks(albumA);
    await service().openTracks(albumB);
    await settle();

    expect(replaced, isEmpty);
    expect(fresh.map((q) => q.original), [albumA]);
  });
}
