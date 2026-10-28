import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/playing_track_lyrics_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../player/fake_audio_backend.dart';
import 'fake_lyrics_readers.dart';

Track _song(String uri) => Track(uri: uri, title: uri);

void main() {
  late FakeEmbeddedLyricsReader embedded;
  late FakeLrcSidecarReader sidecar;
  late ProviderContainer container;

  setUp(() {
    embedded = FakeEmbeddedLyricsReader();
    sidecar = FakeLrcSidecarReader();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(embedded),
        lrcSidecarReaderProvider.overrideWithValue(sidecar),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    // The lyrics view keeps the provider alive while it is shown.
    container.listen(playingTrackLyricsProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  PlayerService service() => container.read(playerServiceProvider.notifier);

  PlayingLyrics? current() => container.read(playingTrackLyricsProvider).value;

  Future<void> settle() => pumpEventQueue();

  test('nothing playing reads nothing', () async {
    await settle();
    expect(current(), isNull);
    expect(embedded.reads, isEmpty);
    expect(sidecar.reads, isEmpty);
  });

  test('the playing track is read and tagged with its uri', () async {
    embedded.byPath['/m/a.mp3'] = (text: 'Words', synced: const []);
    await service().openTracks([_song('/m/a.mp3')]);
    await settle();

    expect(current()!.uri, '/m/a.mp3');
    expect(current()!.lyrics.lines.single.text, 'Words');
  });

  test('a file:// uri is read by its path', () async {
    sidecar.byPath['/m/b c.flac'] = 'From file';
    await service().openTracks([_song('file:///m/b%20c.flac')]);
    await settle();

    expect(current()!.uri, 'file:///m/b%20c.flac');
    expect(sidecar.reads, ['/m/b c.flac']);
  });

  test('a non-file uri reads nothing', () async {
    await service().openTracks([_song('https://example.com/a.mp3')]);
    await settle();

    expect(current(), isNull);
    expect(embedded.reads, isEmpty);
  });

  test('a new track is read again; without lyrics the value is null', () async {
    embedded.byPath['/m/a.mp3'] = (text: 'Words', synced: const []);
    await service().openTracks([_song('/m/a.mp3'), _song('/m/b.mp3')]);
    await settle();
    expect(current()!.uri, '/m/a.mp3');

    await service().next();
    await settle();
    expect(current(), isNull);
    expect(embedded.reads, ['/m/a.mp3', '/m/b.mp3']);
  });

  test('flipping "prefer embedded" reads with the other order', () async {
    embedded.byPath['/m/a.mp3'] = (text: 'From tags', synced: const []);
    sidecar.byPath['/m/a.mp3'] = 'From file';
    await service().openTracks([_song('/m/a.mp3')]);
    await settle();
    expect(current()!.lyrics.source, LyricsSource.sidecar);

    container
        .read(settingsProvider.notifier)
        .setPlayback(const PlaybackPrefs(preferEmbeddedLyrics: true));
    await settle();
    expect(current()!.lyrics.source, LyricsSource.embedded);
  });
}
