import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/media_kit_backend.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';
import 'package:kanaru/core/sources/source_plugin_drops.dart';

import 'fake_audio_backend.dart';

const _pluginA = 'plugin-aaaaaaaaaaaa';
const _pluginB = 'plugin-bbbbbbbbbbbb';

Track remoteTrack(String installId, String itemId) {
  final ref = RemoteSourceRef(installId: installId, itemId: itemId);
  return Track(uri: remoteTrackUri(ref), title: 'r-$itemId', remote: ref);
}

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);

  /// Lets queued stream events and microtasks run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void drop(String installId) =>
      container.read(sourcePluginDropsProvider).add(installId);

  setUp(() {
    backend = FakeAudioBackend();
    // Only the backend is overridden: building the player must not need the
    // stream proxy or the plugin records.
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test(
    'openTracks accepts remote tracks and hands them to the engine',
    () async {
      final tracks = [
        remoteTrack(_pluginA, 'one'),
        Track.fromPath('/music/b.mp3'),
        remoteTrack(_pluginA, 'two'),
      ];

      await service().openTracks(tracks);
      await settle();

      final state = container.read(playerServiceProvider);
      expect(state.queue.original, tracks);
      expect(state.queue.current?.remote?.itemId, 'one');
      expect(backend.calls, ['open(r-one, next: b)']);
    },
  );

  group('a plugin drop', () {
    test('stops playback when the current track belongs to it', () async {
      await service().openTracks([
        remoteTrack(_pluginA, 'one'),
        remoteTrack(_pluginA, 'two'),
      ]);
      await settle();
      backend.emitPlaying.add(true);
      await settle();
      expect(container.read(playerServiceProvider).playing, isTrue);

      drop(_pluginA);
      await settle();

      final state = container.read(playerServiceProvider);
      expect(state.stopped, isTrue);
      expect(state.playing, isFalse);
      expect(
        backend.calls,
        containsAllInOrder(['pause', 'seek(0:00:00.000000)']),
      );
      // The queue stays: the user can start another track.
      expect(state.queue.original, hasLength(2));
    });

    test('a plugin whose track is only queued stops nothing', () async {
      await service().openTracks([
        remoteTrack(_pluginA, 'one'),
        remoteTrack(_pluginB, 'two'),
      ]);
      await settle();
      backend.emitPlaying.add(true);
      await settle();
      final before = List.of(backend.calls);

      drop(_pluginB);
      await settle();

      final state = container.read(playerServiceProvider);
      expect(state.stopped, isFalse);
      expect(state.playing, isTrue);
      expect(backend.calls, before);
    });

    test('a local current track is never stopped by it', () async {
      await service().openTracks([
        Track.fromPath('/music/a.mp3'),
        remoteTrack(_pluginA, 'one'),
      ]);
      await settle();
      backend.emitPlaying.add(true);
      await settle();
      final before = List.of(backend.calls);

      drop(_pluginA);
      await settle();

      expect(container.read(playerServiceProvider).stopped, isFalse);
      expect(backend.calls, before);
    });
  });

  group('redactProxyToken', () {
    test('hides the token in the error mpv reports for a proxy URL', () {
      const message =
          'Failed to open http://127.0.0.1:33445/TOKENTOKENTOKEN/source-plugin/'
          'plugin-abc123def456/missing.';

      final redacted = redactProxyToken(message);

      expect(redacted, isNot(contains('TOKENTOKENTOKEN')));
      expect(
        redacted,
        'Failed to open http://127.0.0.1:33445/***/source-plugin/'
        'plugin-abc123def456/missing.',
      );
    });

    test('leaves other messages as they are', () {
      const local = 'Failed to open /music/a.mp3.';
      const other = 'Failed to open http://example.com/a/b.mp3.';

      expect(redactProxyToken(local), local);
      expect(redactProxyToken(other), other);
    });
  });
}
