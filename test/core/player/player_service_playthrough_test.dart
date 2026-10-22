import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

final songs = [
  for (final name in ['a', 'b', 'c', 'd']) Track.fromPath('/music/$name.mp3'),
];

const _tick = Duration(seconds: 1);

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  int playthrough() => container.read(playerServiceProvider).playthrough;

  /// Lets queued stream events and microtasks run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    // Keeps the notifier alive and subscribed for the whole test.
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  /// Runs [action] and returns how far the playthrough moved.
  Future<int> bump(Future<void> Function() action) async {
    final before = playthrough();
    await action();
    await settle();
    return playthrough() - before;
  }

  group('changes on a fresh start', () {
    test('opening, jumping to the same entry, next and previous', () async {
      expect(await bump(() => service().openTracks(songs)), 1);
      expect(await bump(() => service().jump(0)), 1);
      expect(await bump(() => service().next()), 1);
      expect(await bump(() => service().previous()), 1);
    });

    test('the engine moving on by itself', () async {
      await service().openTracks(songs);
      expect(await bump(() async => backend.advance()), 1);
    });

    test('repeat one looping the track, once per loop', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);

      expect(await bump(() async => backend.emitLooped.add(songs[0])), 1);
      expect(await bump(() async => backend.emitLooped.add(songs[0])), 1);
      expect(await bump(() async => backend.emitLooped.add(songs[0])), 1);
    });

    test('a loop with repeat off changes nothing', () async {
      await service().openTracks(songs);

      expect(await bump(() async => backend.emitLooped.add(songs[0])), 0);
    });

    test('ticks that jump back under repeat one are not a loop', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);
      backend.emitDuration.add(const Duration(seconds: 180));
      await settle();

      expect(
        await bump(() async {
          backend.emitPosition.add(const Duration(seconds: 179));
          backend.emitPosition.add(const Duration(seconds: 180));
          backend.emitPosition.add(Duration.zero);
          backend.emitPosition.add(_tick);
        }),
        0,
      );
    });

    test('a loop of the track before next() is ignored', () async {
      await service().openTracks(songs);
      await service().setRepeat(RepeatMode.one);
      await service().next();

      expect(await bump(() async => backend.emitLooped.add(songs[0])), 0);
    });

    test('adding to an empty queue loads a track', () async {
      expect(await bump(() => service().addToQueue(songs)), 1);
      await service().clearQueue();
      await service().removeTrack(0);
      expect(await bump(() => service().playNext(songs)), 1);
    });

    test('adding after the queue ended loads the added track', () async {
      await service().openTracks(songs.sublist(0, 1));
      backend.emitCompleted.add(true);
      expect(await bump(() => service().addToQueue(songs.sublist(1))), 1);
    });
  });

  group('stays when the same entry keeps playing', () {
    setUp(() async {
      await service().openTracks(songs);
      backend.emitDuration.add(const Duration(seconds: 180));
      await settle();
    });

    final actions = <String, Future<void> Function(PlayerService s)>{
      'seek': (s) => s.seek(const Duration(seconds: 90)),
      'seek to the start': (s) => s.seek(Duration.zero),
      'seekBy': (s) => s.seekBy(const Duration(seconds: 5)),
      'pause': (s) => s.pause(),
      'play when playing': (s) => s.play(),
      'stop': (s) => s.stop(),
      'volume': (s) => s.setVolume(30),
      'repeat': (s) => s.setRepeat(RepeatMode.all),
      'shuffle': (s) => s.toggleShuffle(),
      'move the playing entry': (s) => s.moveTrack(0, 2),
      'add to queue': (s) => s.addToQueue([songs[0]]),
      'play next': (s) => s.playNext([songs[1]]),
      'clear the queue': (s) => s.clearQueue(),
    };
    for (final entry in actions.entries) {
      test(entry.key, () async {
        expect(await bump(() => entry.value(service())), 0);
      });
    }

    test('pausing then playing and plain ticks', () async {
      expect(
        await bump(() async {
          await service().playPause();
          await service().playPause();
          backend.emitPosition.add(_tick);
          backend.emitPosition.add(_tick * 2);
        }),
        0,
      );
    });
  });

  group('session restore', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('kanaru_pt_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('loads the restored track exactly once', () async {
      final file = PlaybackSessionFile('${root.path}/playback-session.json');
      await file.save(
        PlaybackSession(
          tracks: songs,
          order: const [0, 1, 2, 3],
          unshuffledOrder: const [0, 1, 2, 3],
          index: 1,
          shuffled: false,
          repeat: RepeatMode.off,
          position: const Duration(seconds: 83),
          volume: 100,
          volumeBeforeMute: null,
        ),
      );
      await file.flush();

      final restored = FakeAudioBackend();
      final app = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(restored),
          settingsFileProvider.overrideWithValue(
            SettingsFile('${root.path}/settings.json'),
          ),
        ],
      );
      addTearDown(app.dispose);
      app.listen(playerServiceProvider, (_, _) {});

      expect(app.read(playerServiceProvider).playthrough, 0);
      await settle();
      expect(app.read(playerServiceProvider).playthrough, 1);
    });
  });
}
