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

final a = song('a'), b = song('b'), c = song('c'), d = song('d');
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

  group('upNextRun', () {
    test('is 0 with nothing queued next and on an empty queue', () async {
      expect(service().upNextRun, 0);
      await service().openTracks([a, b, c]);
      expect(service().upNextRun, 0);
    });

    test('counts the play next tracks and grows with each call', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y, z]);
      expect(service().upNextRun, 3);
      await service().playNext([d]);
      expect(service().upNextRun, 4);
    });

    test('drops to 0 after jumping past the run', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().jump(3);
      expect(state().queue.current, b);
      expect(service().upNextRun, 0);
      // Going back must not bring the skipped tracks back as a run.
      await service().jump(0);
      expect(state().queue.current, a);
      expect(service().upNextRun, 0);
    });

    test('shrinks by one when the engine moves on', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      backend.advance();
      expect(state().queue.current, x);
      expect(service().upNextRun, 1);
    });

    test('shrinks when a run member is removed', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().removeTrack(1);
      expect(service().upNextRun, 1);
    });

    test('is 0 after clearing the queue or opening a new one', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().clearQueue();
      expect(service().upNextRun, 0);

      await service().playNext([x]);
      expect(service().upNextRun, 1);
      await service().openTracks([a, b]);
      expect(service().upNextRun, 0);
    });

    test('survives shuffling', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().setShuffle(true);
      expect(service().upNextRun, 2);
    });
  });

  group('moveTrack with playNext', () {
    test('keeps a run member in the run when moved inside it', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y, z]);
      await service().moveTrack(1, 3, playNext: true);
      expect(titles(), ['a', 'y', 'z', 'x', 'b', 'c']);
      expect(service().upNextRun, 3);
    });

    test('a plain drag inside the run takes the track out of it', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().moveTrack(1, 2);
      expect(titles(), ['a', 'y', 'x', 'b', 'c']);
      expect(service().upNextRun, 1);
    });

    test('a track dropped into the run joins it', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().moveTrack(4, 2, playNext: true);
      expect(titles(), ['a', 'x', 'c', 'y', 'b']);
      expect(service().upNextRun, 3);
    });

    test('a run member sent to the end leaves the run', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      await service().moveTrack(1, 4);
      expect(titles(), ['a', 'y', 'b', 'c', 'x']);
      expect(service().upNextRun, 1);
    });

    test('same position joins the run with a new queue object', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x]);
      final before = state().queue;
      await service().moveTrack(2, 2, playNext: true);
      expect(identical(state().queue, before), isFalse);
      expect(state().queue.order, before.order);
      expect(service().upNextRun, 2);
    });

    test('same position leaves the run', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x, y]);
      final before = state().queue;
      await service().moveTrack(2, 2);
      expect(identical(state().queue, before), isFalse);
      expect(state().queue.order, before.order);
      expect(service().upNextRun, 1);
    });

    test('same position with unchanged membership touches nothing', () async {
      await service().openTracks([a, b, c]);
      await service().playNext([x]);
      final before = state().queue;
      await service().moveTrack(1, 1, playNext: true);
      await service().moveTrack(3, 3);
      expect(identical(state().queue, before), isTrue);
      expect(service().upNextRun, 1);
    });
  });

  test('tracks jumped over are no longer play next after going back', () async {
    await service().openTracks([d, a, b, c]);
    await service().jump(1);
    await service().playNext([x, y]);
    await service().jump(4);
    expect(state().queue.current, b);
    await service().jump(1);
    expect(state().queue.current, a);
    expect(service().upNextRun, 0);

    await service().playNext([c]);
    expect(state().queue.trackAt(state().queue.index + 1), c);
  });

  test(
    'jumping into the middle of the run drops only the skipped ones',
    () async {
      await service().openTracks([a, b]);
      await service().playNext([x, y, z]);
      await service().jump(2);
      expect(state().queue.current, y);
      expect(service().upNextRun, 1);
      await service().jump(0);
      expect(state().queue.current, a);
      expect(service().upNextRun, 0);
    },
  );

  group('drops that land on or before the playing track', () {
    test('same position on the playing track never joins the run', () async {
      await service().openTracks([a, b, c]);
      await service().moveTrack(0, 0, playNext: true);
      expect(service().upNextRun, 0);
      await service().next();
      await service().jump(0);
      expect(service().upNextRun, 0);
    });

    test('a drop before the playing track is a plain move', () async {
      await service().openTracks([a, b, c]);
      await service().jump(1);
      await service().playNext([x]);
      await service().moveTrack(2, 0, playNext: true);
      expect(service().upNextRun, 0);
      await service().jump(0);
      expect(service().upNextRun, 0);
    });
  });

  group('an earlier track dropped on or after the playing one', () {
    test('on its slot lands right after it and joins the run', () async {
      await service().openTracks([a, b, c]);
      await service().jump(2);
      await service().moveTrack(0, 2, playNext: true);
      expect(titles(), ['b', 'c', 'a']);
      expect(state().queue.current, c);
      expect(service().upNextRun, 1);
    });

    test('past it, inside the run, joins the run', () async {
      await service().openTracks([a, b, c]);
      await service().jump(1);
      await service().playNext([x]);
      await service().moveTrack(0, 2, playNext: true);
      expect(titles(), ['b', 'x', 'a', 'c']);
      expect(service().upNextRun, 2);
    });

    test('a plain drop on its slot stays out of the run', () async {
      await service().openTracks([a, b, c]);
      await service().jump(2);
      await service().moveTrack(0, 2);
      expect(service().upNextRun, 0);
    });
  });

  test('a same-position change does not touch the engine', () async {
    await service().openTracks([a, b, c]);
    await service().playNext([x]);
    backend.calls.clear();
    await service().moveTrack(2, 2, playNext: true);
    expect(service().upNextRun, 2);
    expect(backend.calls, isEmpty);
  });

  test('a same-position change is saved with the session', () async {
    final root = Directory.systemTemp.createTempSync('kanaru_up_next_move_');
    addTearDown(() => root.deleteSync(recursive: true));
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

    final first = launch();
    final player = first.read(playerServiceProvider.notifier);
    await player.openTracks([a, b, c]);
    await player.playNext([x]);
    await player.pause();
    await player.moveTrack(2, 2, playNext: true);
    final file = first.read(playbackSessionFileProvider);
    first.dispose();
    await file?.flush();

    final second = launch();
    addTearDown(second.dispose);
    expect(second.read(playerServiceProvider.notifier).upNextRun, 2);
  });

  test('a restored session restores the run', () async {
    final root = Directory.systemTemp.createTempSync('kanaru_up_next_run_');
    addTearDown(() => root.deleteSync(recursive: true));
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

    final first = launch();
    await first.read(playerServiceProvider.notifier).openTracks([a, b, c]);
    await first.read(playerServiceProvider.notifier).playNext([x, y]);
    await first.read(playerServiceProvider.notifier).pause();
    final file = first.read(playbackSessionFileProvider);
    first.dispose();
    await file?.flush();

    final second = launch();
    addTearDown(second.dispose);
    expect(second.read(playerServiceProvider.notifier).upNextRun, 2);
  });
}
