import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';

void main() {
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  String? path() => container.read(playingTrackPathProvider);
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
  });

  test('is null with nothing in the queue', () {
    expect(path(), isNull);
  });

  test('is the path of the current track', () async {
    await player().openTracks(const [
      Track(uri: '/music/a.mp3', title: 'a'),
      Track(uri: '/music/b.mp3', title: 'b'),
    ]);
    expect(path(), '/music/a.mp3');
  });

  test('keeps its value on pause and seek, changes on next', () async {
    await player().openTracks(const [
      Track(uri: '/music/a.mp3', title: 'a'),
      Track(uri: '/music/b.mp3', title: 'b'),
    ]);
    container.listen(playingTrackPathProvider, (_, _) {});
    await flush();
    const a = '/music/a.mp3';

    expect(container.read(playerServiceProvider).playing, isTrue);
    await player().pause();
    await flush();
    expect(container.read(playerServiceProvider).playing, isFalse);
    expect(path(), a);

    await player().seek(const Duration(seconds: 5));
    await flush();
    expect(path(), a);

    await player().next();
    await flush();
    expect(path(), '/music/b.mp3');
  });
}
