import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/queue_translation_choice.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/session/playback_session_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../player/fake_audio_backend.dart';

const _key = queueTranslationSessionKey;
final _serviceY = TranslationServiceId.tryParse('plugin-bbbbbbbbbbbb')!;

List<Track> _tracks(List<String> names) => [
  for (final n in names) Track.fromPath('/music/$n.mp3'),
];

void main() {
  late Directory root;
  late String sessionPath;
  ProviderContainer? live;
  late FakeAudioBackend backend;

  /// A player on the saved session with the queue choice alive, as the app
  /// shell keeps it, past the restore so saving goes on.
  Future<ProviderContainer> launch() async {
    backend = FakeAudioBackend();
    final app = ProviderContainer(
      overrides: [
        sessionCoverDirectoryProvider.overrideWithValue(null),
        audioBackendProvider.overrideWithValue(backend),
        settingsFileProvider.overrideWithValue(
          SettingsFile('${root.path}/settings.json'),
        ),
      ],
    );
    app.listen(playerServiceProvider, (_, _) {});
    app.listen(queueTranslationChoiceProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    backend.emitDuration.add(const Duration(minutes: 3));
    await Future<void>.delayed(Duration.zero);
    return app;
  }

  PlayerService player() => live!.read(playerServiceProvider.notifier);
  ScopedTranslationChoice? choice() =>
      live!.read(queueTranslationChoiceProvider);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> quit() async {
    final app = live;
    if (app == null) return;
    live = null;
    final file = app.read(playbackSessionFileProvider);
    app.dispose();
    await file?.flush();
  }

  Future<void> restart() async {
    await quit();
    live = await launch();
  }

  /// The extra on disk after flushing the live player.
  Future<Object?> saved() async {
    await player().flushSession();
    return PlaybackSessionFile(sessionPath).load()!.extras[_key];
  }

  Future<void> seed(
    List<Track> tracks, {
    Map<String, Object?> extras = const {},
  }) async {
    final file = PlaybackSessionFile(sessionPath);
    await file.save(
      PlaybackSession(
        tracks: tracks,
        order: [for (var i = 0; i < tracks.length; i++) i],
        extras: extras,
      ),
    );
    await file.flush();
  }

  Map<String, Object?> extra(PlayQueue queue, {int at = 7}) => {
    'service': _serviceY.value,
    'tune': <String, String>{},
    'chosenAt': at,
    'queueKey': queueFingerprint(queue),
  };

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_queue_choice_');
    sessionPath = '${root.path}/playback-session.json';
  });

  tearDown(() async {
    await quit();
    root.deleteSync(recursive: true);
  });

  final abc = _tracks(['a', 'b', 'c']);

  /// Launches on [abc] and chooses Y for the queue.
  Future<void> launchWithChoice({int at = 7}) async {
    await seed(abc);
    live = await launch();
    live!
        .read(queueTranslationChoiceProvider.notifier)
        .set(_serviceY, chosenAt: at);
    await settle();
  }

  group('queueFingerprint', () {
    test('is the same for a shuffled copy and a reshuffled round', () {
      final plain = PlayQueue.open(abc, 0);
      final shuffled = plain.shuffle(Random(1));
      final again = shuffled.shuffle(Random(2));
      expect(shuffled.order, isNot(plain.order));
      expect(queueFingerprint(shuffled), queueFingerprint(plain));
      expect(queueFingerprint(again), queueFingerprint(plain));
    });

    test('differs for other tracks and for another open order', () {
      final a = queueFingerprint(PlayQueue.open(abc, 0));
      expect(
        queueFingerprint(PlayQueue.open(_tracks(['a', 'b', 'x']), 0)),
        isNot(a),
      );
      expect(
        queueFingerprint(PlayQueue.open(abc.reversed.toList(), 0)),
        isNot(a),
      );
      expect(
        queueFingerprint(PlayQueue.open(_tracks(['ab', 'c']), 0)),
        isNot(queueFingerprint(PlayQueue.open(_tracks(['a', 'bc']), 0))),
      );
    });
  });

  group('saved with the session', () {
    test('a choice is written with the queue key', () async {
      await launchWithChoice(at: 42);
      final value = await saved() as Map;
      expect(value['service'], _serviceY.value);
      expect(value['chosenAt'], 42);
      expect(value['tune'], isEmpty);
      expect(
        value['queueKey'],
        queueFingerprint(live!.read(playerServiceProvider).queue),
      );
    });

    test('a tune is kept', () async {
      await seed(abc);
      live = await launch();
      live!
          .read(queueTranslationChoiceProvider.notifier)
          .set(
            _serviceY,
            tune: const {'model': 'm', 'style': 's'},
            chosenAt: 3,
          );
      await restart();
      expect(choice()?.tune, {'model': 'm', 'style': 's'});
    });

    test('survives a restart', () async {
      await launchWithChoice();
      await restart();
      expect(choice()?.service, _serviceY);
      expect(choice()?.chosenAt, 7);
    });

    test('set does nothing on an empty queue', () async {
      await seed(abc);
      live = await launch();
      await player().clearQueue();
      await player().removeTrack(0);
      live!
          .read(queueTranslationChoiceProvider.notifier)
          .set(_serviceY, chosenAt: 1);
      expect(choice(), isNull);
    });

    test('a key of another queue is dropped and cleared', () async {
      await seed(
        abc,
        extras: {
          _key: extra(PlayQueue.open(_tracks(['x', 'y']), 0)),
        },
      );
      live = await launch();
      expect(choice(), isNull);
      expect(await saved(), isNull);
    });

    for (final (name, bad) in <(String, Object)>[
      ('not a map', 5),
      ('service that is not a plugin id', {'service': 'nope'}),
      (
        'chosenAt that is not an int',
        {...extra(PlayQueue.open(abc, 0)), 'chosenAt': 'x'},
      ),
      (
        'tune with a non-string value',
        {
          ...extra(PlayQueue.open(abc, 0)),
          'tune': {'a': 1},
        },
      ),
      (
        'missing queue key',
        {...extra(PlayQueue.open(abc, 0))}..remove('queueKey'),
      ),
    ]) {
      test('malformed extra ($name) is dropped and cleared', () async {
        await seed(abc, extras: {_key: bad});
        live = await launch();
        expect(choice(), isNull);
        expect(await saved(), isNull);
      });
    }
  });

  group('when the choice ends', () {
    test('opening other tracks', () async {
      await launchWithChoice();
      await player().openTracks(_tracks(['x', 'y']));
      await settle();
      expect(choice(), isNull);
      expect(await saved(), isNull);
    });

    test('opening the same tracks at another index keeps it', () async {
      await launchWithChoice();
      await player().openTracks(abc, start: 2);
      await settle();
      expect(choice()?.service, _serviceY);
      await restart();
      expect(choice()?.service, _serviceY);
    });

    test('with shuffle on, opening the same tracks keeps it', () async {
      await launchWithChoice();
      await player().setShuffle(true);
      await player().openTracks(abc, start: 1);
      await player().openTracks(abc, start: 2);
      await settle();
      expect(choice()?.service, _serviceY);
      await restart();
      expect(choice()?.service, _serviceY);
    });

    test('opening the same tracks shuffled keeps it', () async {
      await launchWithChoice();
      await player().openShuffled(abc);
      await settle();
      expect(choice()?.service, _serviceY);
    });

    test('clearing a queue of several songs', () async {
      await launchWithChoice();
      await player().clearQueue();
      await settle();
      expect(choice(), isNull);
      expect(await saved(), isNull);
    });

    test('removing every song', () async {
      await launchWithChoice();
      await player().removeTrack(2);
      await player().removeTrack(1);
      await player().removeTrack(0);
      await settle();
      expect(choice(), isNull);
      expect(await saved(), isNull);
    });

    test(
      'the same songs added back after it emptied do not revive it',
      () async {
        await launchWithChoice();
        for (var i = 2; i >= 0; i--) {
          await player().removeTrack(i);
        }
        await player().addToQueue(abc);
        await settle();
        expect(choice(), isNull);
      },
    );

    test('opening other tracks after the player rebuilt', () async {
      await launchWithChoice();
      await player().flushSession();
      live!.invalidate(playerServiceProvider);
      live!.read(playerServiceProvider);
      await settle();
      await settle();
      expect(choice()?.service, _serviceY);
      await player().openTracks(_tracks(['x', 'y']));
      await settle();
      expect(choice(), isNull);
    });
  });

  group('when the choice stays', () {
    test('add to queue and play next, also after a restart', () async {
      await launchWithChoice();
      await player().addToQueue(_tracks(['d']));
      await player().playNext(_tracks(['e']));
      await settle();
      expect(choice()?.service, _serviceY);
      await restart();
      expect(choice()?.service, _serviceY);
      expect(live!.read(playerServiceProvider).queue.order, hasLength(5));
    });

    test('removing and moving a song', () async {
      await launchWithChoice();
      await player().moveTrack(0, 2);
      await player().removeTrack(1);
      await settle();
      expect(choice()?.service, _serviceY);
      await restart();
      expect(choice()?.service, _serviceY);
    });

    test('the key follows the queue edited before it was read', () async {
      await seed(abc, extras: {_key: extra(PlayQueue.open(abc, 0))});
      live = await launch();
      await player().addToQueue(_tracks(['d']));
      await settle();
      final original = extra(PlayQueue.open(abc, 0))['queueKey'];
      expect((await saved() as Map)['queueKey'], isNot(original));
      await restart();
      expect(choice()?.service, _serviceY);
    });

    test('toggling shuffle leaves the key alone', () async {
      await launchWithChoice();
      final before = (await saved() as Map)['queueKey'];
      await player().setShuffle(true);
      await player().setShuffle(false);
      await player().setShuffle(true);
      await settle();
      expect((await saved() as Map)['queueKey'], before);
      expect(choice()?.service, _serviceY);
    });

    test('a new round of repeat all shuffled leaves the key alone', () async {
      await launchWithChoice();
      final before = (await saved() as Map)['queueKey'];
      await player().setShuffle(true);
      await player().setRepeat(RepeatMode.allShuffled);
      final order = live!.read(playerServiceProvider).queue.order;
      // Past the end of the pass: the next round is a fresh shuffle.
      for (var i = 0; i < 4; i++) {
        await player().next();
      }
      await settle();
      // A new round makes a new order list (its content may repeat).
      expect(live!.read(playerServiceProvider).queue.order, isNot(same(order)));
      expect((await saved() as Map)['queueKey'], before);
      expect(choice()?.service, _serviceY);
    });
  });

  for (final playing in [false, true]) {
    test('opening other tracks (playing: $playing) leaves the old key on disk '
        'until the next write, so a restart drops the choice', () async {
      await launchWithChoice();
      if (playing) await player().jump(0);
      await player().flushSession();
      await player().openTracks(_tracks(['x', 'y']));
      // A killed app: only writes already started reach the disk.
      await live!.read(playbackSessionFileProvider)!.flush();
      final onDisk = PlaybackSessionFile(sessionPath).load()!;
      final extra = onDisk.extras[_key] as Map?;
      final newKey = queueFingerprint(live!.read(playerServiceProvider).queue);
      expect(extra == null || extra['queueKey'] != newKey, isTrue);
    });
  }

  test('clear drops the choice and the saved value', () async {
    await launchWithChoice();
    live!.read(queueTranslationChoiceProvider.notifier).clear();
    expect(choice(), isNull);
    expect(await saved(), isNull);
  });
}
