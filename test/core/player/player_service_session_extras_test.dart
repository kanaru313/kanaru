import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/session/playback_session_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

void main() {
  late Directory root;
  late String sessionPath;
  ProviderContainer? live;
  late FakeAudioBackend backend;

  /// A player on the seeded session, past the restore: a loaded track lets
  /// saving go on.
  Future<ProviderContainer> launch({bool loaded = true}) async {
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
    await Future<void>.delayed(Duration.zero);
    if (loaded) {
      backend.emitDuration.add(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
    }
    return app;
  }

  PlayerService service() => live!.read(playerServiceProvider.notifier);

  Future<void> quit() async {
    final app = live;
    if (app == null) return;
    live = null;
    final file = app.read(playbackSessionFileProvider);
    app.dispose();
    await file?.flush();
  }

  PlaybackSession onDisk() => PlaybackSessionFile(sessionPath).load()!;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_session_extras_');
    sessionPath = '${root.path}/playback-session.json';
  });

  tearDown(() async {
    await quit();
    root.deleteSync(recursive: true);
  });

  Future<void> seed(Map<String, Object?> extras) async {
    final file = PlaybackSessionFile(sessionPath);
    await file.save(
      PlaybackSession(
        tracks: [Track.fromPath('/music/a.mp3')],
        order: const [0],
        extras: extras,
      ),
    );
    await file.flush();
  }

  test('restoredSessionExtra returns the saved value', () async {
    await seed({
      'k': {'n': 1},
    });
    live = await launch();
    expect(service().restoredSessionExtra('k'), {'n': 1});
    expect(service().restoredSessionExtra('missing'), isNull);
  });

  test('a set extra reaches the file', () async {
    await seed(const {});
    live = await launch();
    service().setSessionExtra('k', {'v': 2});
    await service().flushSession();
    await quit();
    expect(onDisk().extras, {
      'k': {'v': 2},
    });
  });

  test('null removes the key', () async {
    await seed({'k': 1, 'j': 2});
    live = await launch();
    service().setSessionExtra('k', null);
    await service().flushSession();
    expect(onDisk().extras, {'j': 2});
  });

  test(
    'a value that is not JSON is refused and the session still saves',
    () async {
      await seed(const {});
      live = await launch();
      service().setSessionExtra('bad', Object());
      service().setSessionExtra('good', 1);
      await service().flushSession();
      expect(onDisk().extras, {'good': 1});
    },
  );

  test('extras survive a rebuild of the player', () async {
    await seed({'k': 1});
    live = await launch();
    final player = service();
    player.setSessionExtra('k', 5);
    live!.invalidate(playerServiceProvider);
    live!.read(playerServiceProvider);
    expect(service(), same(player));
    await service().flushSession();
    expect(onDisk().extras, {'k': 5});
    // The restored value stays the one of the first build.
    expect(service().restoredSessionExtra('k'), 1);
  });

  test(
    'an extra set while saving is frozen survives a rebuild and is written',
    () async {
      await seed({'k': 1});
      live = await launch(loaded: false);
      service().setSessionExtra('k', 7);
      live!.invalidate(playerServiceProvider);
      live!.read(playerServiceProvider);
      await Future<void>.delayed(Duration.zero);
      backend.emitDuration.add(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      await service().flushSession();
      expect(onDisk().extras, {'k': 7});
    },
  );

  test('a value with a failing toJson is refused, saving goes on', () async {
    await seed(const {});
    live = await launch();
    final port = ReceivePort();
    addTearDown(port.close);
    service().setSessionExtra('bad', _Holder(port));
    await service().setVolume(33);
    await service().flushSession();
    final saved = onDisk();
    expect(saved.volume, 33);
    expect(saved.extras, isEmpty);
  });

  test('a map changed after the call does not reach the file', () async {
    await seed(const {});
    live = await launch();
    final value = <String, Object?>{'n': 1};
    service().setSessionExtra('k', value);
    value['n'] = double.nan;
    value['port'] = ReceivePort()..close();
    await service().setVolume(44);
    await service().flushSession();
    final saved = onDisk();
    expect(saved.volume, 44);
    expect(saved.extras, {
      'k': {'n': 1},
    });
  });

  test('restoredSessionExtra returns a copy', () async {
    await seed({
      'k': {'n': 1},
    });
    live = await launch();
    (service().restoredSessionExtra('k')! as Map<String, Object?>)['n'] = 9;
    expect(service().restoredSessionExtra('k'), {'n': 1});
  });
}

/// Encodes to something that cannot be sent to another isolate.
class _Holder {
  _Holder(this.port);

  final ReceivePort port;

  Object? toJson() => port;
}
