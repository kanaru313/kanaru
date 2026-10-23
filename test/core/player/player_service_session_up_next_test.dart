import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/session/playback_session_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c');
final x = song('x'), y = song('y'), z = song('z');

/// "Play next" tracks that have not played yet survive a restart: the next
/// "play next" still goes behind them.
void main() {
  late Directory root;
  ProviderContainer? live;

  ProviderContainer launch() {
    final app = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        settingsFileProvider.overrideWithValue(
          SettingsFile('${root.path}/settings.json'),
        ),
      ],
    );
    app.listen(playerServiceProvider, (_, _) {});
    return app;
  }

  PlayerService service() => live!.read(playerServiceProvider.notifier);
  PlayerState state() => live!.read(playerServiceProvider);

  Future<void> quit() async {
    final app = live;
    if (app == null) return;
    live = null;
    final file = app.read(playbackSessionFileProvider);
    app.dispose();
    await file?.flush();
  }

  Map<String, Object?> savedJson() =>
      jsonDecode(File('${root.path}/playback-session.json').readAsStringSync())
          as Map<String, Object?>;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kanaru_player_up_next_');
  });

  tearDown(() async {
    await quit();
    root.deleteSync(recursive: true);
  });

  test('a play next after a restart goes behind the earlier ones', () async {
    live = launch();
    await service().openTracks([a, b, c]);
    await service().playNext([x, y]);
    await service().pause();
    await quit();
    expect(savedJson()['upNext'], [3, 4]);

    live = launch();
    expect(state().queue.tracks, [a, x, y, b, c]);
    await Future<void>.delayed(Duration.zero);
    await service().playNext([z]);
    expect(state().queue.tracks, [a, x, y, z, b, c]);
  });

  test('a play next track that played is no longer marked', () async {
    live = launch();
    await service().openTracks([a, b, c]);
    await service().playNext([x, y]);
    await service().next();
    expect(state().queue.current, x);
    await service().pause();
    await quit();
    expect(savedJson()['upNext'], [4]);

    live = launch();
    await Future<void>.delayed(Duration.zero);
    await service().playNext([z]);
    expect(state().queue.tracks, [a, x, y, z, b, c]);
  });

  test('a session saved without the key restores no play next', () async {
    live = launch();
    await service().openTracks([a, b, c]);
    await service().playNext([x]);
    await service().pause();
    await quit();
    final json = savedJson()..remove('upNext');
    File('${root.path}/playback-session.json')
        .writeAsStringSync(jsonEncode(json));

    live = launch();
    expect(state().queue.tracks, [a, x, b, c]);
    await Future<void>.delayed(Duration.zero);
    await service().playNext([z]);
    // Nothing is marked, so z goes right after the playing track.
    expect(state().queue.tracks, [a, z, x, b, c]);
  });
}
