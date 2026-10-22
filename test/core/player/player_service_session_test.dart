import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/session/playback_session_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c');

void main() {
  late Directory root;
  late String sessionPath;
  late FakeAudioBackend backend;
  ProviderContainer? live;

  /// A player as the app builds it, with its settings (and so its session)
  /// in the temporary directory.
  ProviderContainer launch({String? coverDirectory}) {
    backend = FakeAudioBackend();
    final app = ProviderContainer(
      overrides: [
        sessionCoverDirectoryProvider.overrideWithValue(coverDirectory),
        audioBackendProvider.overrideWithValue(backend),
        settingsFileProvider.overrideWithValue(
          SettingsFile('${root.path}/settings.json'),
        ),
      ],
    );
    // Keeps the notifier alive and subscribed for the whole test.
    app.listen(playerServiceProvider, (_, _) {});
    return app;
  }

  PlayerService service() => live!.read(playerServiceProvider.notifier);
  PlayerState state() => live!.read(playerServiceProvider);

  /// Lets the restore scheduled by the first read reach the engine.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Quits: disposes the player and waits for its last write.
  Future<void> quit() async {
    final app = live;
    if (app == null) return;
    live = null;
    final file = app.read(playbackSessionFileProvider);
    app.dispose();
    await file?.flush();
  }

  Future<void> store(PlaybackSession session) async {
    final file = PlaybackSessionFile(sessionPath);
    await file.save(session);
    await file.flush();
  }

  // Shuffled to c, b, a; on b, 1:23 in, muted from 40.
  final session = PlaybackSession(
    tracks: [a, b, c],
    order: const [2, 1, 0],
    unshuffledOrder: const [0, 1, 2],
    index: 1,
    shuffled: true,
    repeat: RepeatMode.all,
    position: const Duration(seconds: 83),
    volume: 0,
    volumeBeforeMute: 40,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_player_session_');
    sessionPath = '${root.path}/playback-session.json';
  });

  tearDown(() async {
    await quit();
    root.deleteSync(recursive: true);
  });

  test('restores the last session paused', () async {
    await store(session);
    live = launch();

    final first = state();
    expect(first.queue.tracks, [c, b, a]);
    expect(first.queue.current, b);
    expect(first.queue.shuffled, isTrue);
    expect(first.queue.unshuffledOrder, [0, 1, 2]);
    expect(first.queue.repeat, RepeatMode.all);
    expect(first.position, const Duration(seconds: 83));
    expect(first.volume, 0);
    expect(first.volumeBeforeMute, 40);
    expect(first.playing, isFalse);

    await settle();
    expect(backend.calls, [
      'setVolume(0.0)',
      'setRepeat(all)',
      'open(b, next: a, paused, at 0:01:23.000000)',
    ]);
    expect(state().playing, isFalse);
    expect(state().position, const Duration(seconds: 83));

    // MPRIS clients see the restored (muted) volume from the first reply.
    final ids = MprisTrackIds()..observe(first.queue);
    expect(
      playerProperties(first, ids, artUri: null)['Volume'],
      const DBusDouble(0),
    );

    // Unmute brings back the volume from before the restart.
    await service().toggleMute();
    expect(state().volume, 40);
    expect(
      playerProperties(state(), ids, artUri: null)['Volume'],
      const DBusDouble(0.4),
    );
  });

  test('quit and relaunch comes back where it was paused', () async {
    live = launch();
    await service().openTracks([a, b, c], start: 1);
    await service().setVolume(35);
    await service().seek(const Duration(seconds: 70));
    await service().pause();
    await quit();

    live = launch();
    expect(state().queue.current, b);
    expect(state().position, const Duration(seconds: 70));
    expect(state().volume, 35);
    await settle();
    expect(backend.calls.last, 'open(b, next: c, paused, at 0:01:10.000000)');
  });

  test('a rebuild while playing restores the track paused', () async {
    live = launch();
    await service().openTracks([a, b, c], start: 1);
    expect(state().playing, isTrue);
    backend.calls.clear();

    live!.invalidate(playerServiceProvider);
    expect(state().queue.current, b);
    await settle();

    expect(backend.calls.where((call) => call.startsWith('open')), [
      'open(b, next: c, paused)',
    ]);
    expect(state().playing, isFalse);
  });

  test('a session that ended comes back on its last track at 0:00', () async {
    live = launch();
    await service().openTracks([a, b]);
    await service().next();
    backend.emitDuration.add(const Duration(seconds: 100));
    backend.emitPosition.add(const Duration(seconds: 99));
    backend.emitCompleted.add(true);
    expect(state().stopped, isTrue);
    await quit();

    live = launch();
    expect(state().queue.current, b);
    expect(state().position, Duration.zero);
    expect(state().playing, isFalse);
  });

  test('a corrupt file starts empty and plays nothing', () async {
    File(sessionPath).writeAsStringSync('{"version": 1, "tracks": [');
    live = launch();

    expect(state().queue.isEmpty, isTrue);
    await settle();
    expect(backend.calls.where((call) => call.startsWith('open')), isEmpty);
    expect(File('$sessionPath.invalid').existsSync(), isTrue);
  });

  test('a restored track that fails moves on paused, file untouched', () async {
    await store(session);
    final before = File(sessionPath).readAsBytesSync();
    live = launch();
    state();
    await settle();

    backend.fail(b);
    backend.emitCompleted.add(true);

    expect(backend.calls.last, 'open(a, next: c, paused)');
    expect(state().playing, isFalse);
    await quit();
    expect(File(sessionPath).readAsBytesSync(), before);
  });

  test('a restored track that loads lets saving go on', () async {
    await store(session);
    live = launch();
    state();
    await settle();

    backend.emitDuration.add(const Duration(seconds: 200));
    backend.advance(); // the engine moved on to a by itself
    await quit();

    final back = PlaybackSessionFile(sessionPath).load();
    expect(back?.index, 2);
    expect(back?.toQueue().current, a);
  });

  test('a rejected open leaves a restored session frozen', () async {
    await store(session);
    final before = File(sessionPath).readAsBytesSync();
    live = launch();
    state();
    await settle();

    await expectLater(
      service().openTracks([a, b], start: 5),
      throwsArgumentError,
    );
    backend.advance(); // a change that would be saved if it were not frozen
    await settle();
    await quit();

    expect(File(sessionPath).readAsBytesSync(), before);
  });

  test('the user playing right away wins over the restore', () async {
    await store(session);
    live = launch();
    state();
    // Both run before the restore microtask gets a turn.
    final volume = service().setVolume(70);
    final open = service().openTracks([c]);
    await Future.wait([volume, open]);
    await settle();

    expect(backend.calls.where((call) => call.startsWith('open')), [
      'open(c, next: c)', // repeat all came back too
    ]);
    expect(state().volume, 70);
    expect(backend.calls, contains('setRepeat(all)'));
    expect(
      backend.calls.where((call) => call.startsWith('setVolume')).toSet(),
      {'setVolume(70.0)'},
    );
  });

  group('a command sent before the restore ran', () {
    Future<List<String>> opensAfter(
      Future<void> Function(PlayerService) command,
    ) async {
      await store(session);
      live = launch();
      state();
      await command(service());
      await settle();
      return [
        for (final call in backend.calls)
          if (call.startsWith('open')) call,
      ];
    }

    test('a volume change still loads the restored track', () async {
      final opens = await opensAfter((s) => s.setVolume(70));

      expect(opens, ['open(b, next: a, paused, at 0:01:23.000000)']);
      expect(backend.calls, contains('setVolume(70.0)'));
    });

    test('a seek loads the restored track where it seeked to', () async {
      final opens = await opensAfter(
        (s) => s.seek(const Duration(seconds: 10)),
      );

      expect(opens, ['open(b, next: a, paused, at 0:00:10.000000)']);
    });

    test('play loads the restored track playing', () async {
      final opens = await opensAfter((s) => s.play());

      expect(opens, ['open(b, next: a, at 0:01:23.000000)']);
      expect(state().playing, isTrue);
    });

    test('a queue edit loads the current track of the edited queue', () async {
      final opens = await opensAfter((s) => s.removeTrack(0));

      expect(opens, ['open(b, next: a, paused, at 0:01:23.000000)']);
      expect(state().queue.tracks, [b, a]);
    });
  });

  group('any command lets a restored session be saved again', () {
    final commands = <String, Future<void> Function(PlayerService)>{
      'play': (s) async {
        await s.play();
        backend.emitPosition.add(const Duration(seconds: 90));
      },
      'seek': (s) => s.seek(const Duration(seconds: 5)),
      'setVolume': (s) => s.setVolume(50),
      'toggleMute': (s) => s.toggleMute(),
      'setShuffle': (s) => s.setShuffle(false),
      'setRepeat': (s) => s.setRepeat(RepeatMode.off),
      'moveTrack': (s) => s.moveTrack(2, 0),
      'removeTrack': (s) => s.removeTrack(0),
      'clearQueue': (s) => s.clearQueue(),
      'stop': (s) => s.stop(),
    };
    for (final MapEntry(key: name, value: command) in commands.entries) {
      test(name, () async {
        await store(session);
        final before = File(sessionPath).readAsBytesSync();
        live = launch();
        state();
        await settle();

        await command(service());
        await settle(); // seeked events arrive a microtask later
        await quit();

        expect(File(sessionPath).readAsBytesSync(), isNot(before));
      });
    }
  });

  test('an edited queue comes back as it was', () async {
    final d = song('d'), e = song('e');
    live = launch();
    await service().openTracks([a, b, c], start: 1);
    await service().playNext([d]);
    await service().addToQueue([e]);
    await service().removeTrack(3);
    await service().setShuffle(true);
    await service().setShuffle(false);
    await service().setShuffle(true);
    final before = state().queue;
    await quit();

    live = launch();
    final after = state().queue;
    expect(after.tracks, before.tracks);
    expect(after.current, before.current);
    expect(after.shuffled, isTrue);
    expect(after.unshuffle().tracks, before.unshuffle().tracks);
    // A track removed in the last session is no longer kept.
    expect(after.original.length, 4);
  });

  test('clearing the queue is saved without the dropped tracks', () async {
    live = launch();
    await service().openTracks([a, b, c], start: 1);
    await service().addToQueue([song('d')]);
    await service().clearQueue();
    await quit();

    live = launch();
    expect(state().queue.original, [b]);
    expect(state().queue.order, [0]);
  });

  test('without a settings file nothing is saved', () async {
    backend = FakeAudioBackend();
    live = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    live!.listen(playerServiceProvider, (_, _) {});

    expect(live!.read(playbackSessionFileProvider), isNull);
    await service().openTracks([a, b]);
    await service().pause();
    expect(state().queue.current, a);
  });

  group('flushSession', () {
    test('writes a volume change before the debounce would', () async {
      live = launch();
      await service().openTracks([a, b]);
      await service().setVolume(35);

      await service().flushSession();

      expect(PlaybackSessionFile(sessionPath).load()?.volume, 35);
    });

    test('writes the paused position', () async {
      live = launch();
      await service().openTracks([a, b, c], start: 1);
      await service().seek(const Duration(seconds: 70));
      await service().pause();

      await service().flushSession();

      final saved = PlaybackSessionFile(sessionPath).load();
      expect(saved?.position, const Duration(seconds: 70));
    });

    test('without a settings file completes', () async {
      backend = FakeAudioBackend();
      live = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      live!.listen(playerServiceProvider, (_, _) {});

      await service().flushSession();
    });
  });

  group('the restored start position', () {
    final long = Track(
      uri: '/music/long.mp3',
      title: 'long',
      duration: const Duration(minutes: 3),
    );

    PlaybackSession savedAt(Duration position, {Track? track}) =>
        PlaybackSession(
          tracks: [track ?? long, c],
          order: const [0, 1],
          position: position,
        );

    List<String> opens() => [
      for (final call in backend.calls)
        if (call.startsWith('open')) call,
    ];

    test(
      'at the track length restarts at 0, in state and in the file',
      () async {
        await store(savedAt(const Duration(minutes: 3)));
        live = launch();
        expect(state().position, Duration.zero);
        await settle();
        expect(opens(), ['open(long, next: c, paused)']);

        await service().setVolume(50);
        await quit();

        expect(
          PlaybackSessionFile(sessionPath).load()?.position,
          Duration.zero,
        );
      },
    );

    test('just below the length opens there', () async {
      await store(savedAt(const Duration(minutes: 2, seconds: 59)));
      live = launch();
      await settle();

      expect(opens(), ['open(long, next: c, paused, at 0:02:59.000000)']);
    });

    test('a track with a zero duration is not clamped', () async {
      final zero = Track(
        uri: '/music/zero.mp3',
        title: 'zero',
        duration: Duration.zero,
      );
      await store(savedAt(const Duration(seconds: 30), track: zero));
      live = launch();
      await settle();

      expect(opens(), ['open(zero, next: c, paused, at 0:00:30.000000)']);
    });

    test('a track without a duration is not clamped', () async {
      await store(savedAt(const Duration(hours: 5), track: a));
      live = launch();
      await settle();

      expect(opens(), ['open(a, next: c, paused, at 5:00:00.000000)']);
    });
  });

  group('a stop made before the restore ran', () {
    test('loads the track paused at 0 and stays stopped', () async {
      await store(session);
      live = launch();
      state();

      await service().stop();
      await settle();

      final calls = backend.calls;
      expect(
        [
          for (final call in calls)
            if (call.startsWith('open')) call,
        ],
        ['open(b, next: a, paused)'],
      );
      final open = calls.indexOf('open(b, next: a, paused)');
      expect(
        calls.indexOf('setVolume(0.0)'),
        allOf(isNonNegative, lessThan(open)),
      );
      expect(
        calls.indexOf('setRepeat(all)'),
        allOf(isNonNegative, lessThan(open)),
      );
      expect(state().position, Duration.zero);
      expect(state().stopped, isTrue);
      expect(state().playing, isFalse);

      await service().play();
      expect(backend.calls.last, 'play');
      expect(state().stopped, isFalse);
    });

    test('a queue that ran out loads nothing; play restarts it', () async {
      await store(
        PlaybackSession(
          tracks: [a, b],
          order: const [0, 1],
          index: 1,
          position: const Duration(seconds: 5),
        ),
      );
      live = launch();
      state();

      await service().removeTrack(1);
      await settle();

      expect(backend.calls.where((c) => c.startsWith('open')), isEmpty);
      expect(state().stopped, isTrue);

      await service().play();
      expect(backend.calls.last, 'open(a, next: null)');
    });
  });

  test('restored tracks get their cover from the key and the folder', () async {
    const dir = '/cache/covers/512';
    final key = 'ab/${'ab'.padRight(64, '0')}.jpg';
    final file = PlaybackSessionFile(sessionPath, coverDirectory: dir);
    await file.save(
      PlaybackSession(
        tracks: [Track(uri: '/music/t.mp3', title: 't', artUri: '$dir/$key')],
        order: const [0],
      ),
    );
    await file.flush();

    live = launch(coverDirectory: '/moved/covers/512');

    expect(state().queue.current?.artUri, '/moved/covers/512/$key');
  });

  test('a restored cover key is not written back unchanged', () async {
    const dir = '/cache/covers/512';
    final key = 'ab/${'ab'.padRight(64, '0')}.jpg';
    final file = PlaybackSessionFile(sessionPath, coverDirectory: dir);
    await file.save(
      PlaybackSession(
        tracks: [Track(uri: '/music/t.mp3', title: 't', artUri: '$dir/$key')],
        order: const [0],
      ),
    );
    await file.flush();
    final before = File(sessionPath).readAsBytesSync();
    final modified = File(sessionPath).lastModifiedSync();

    live = launch(coverDirectory: dir);
    state();
    await settle();
    // A track loading lets saving go on.
    backend.emitDuration.add(const Duration(minutes: 3));
    await settle();
    await quit();

    expect(File(sessionPath).readAsBytesSync(), before);
    expect(File(sessionPath).lastModifiedSync(), modified);
  });
}
