import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/player/fake_audio_backend.dart';

void main() {
  const split = NowPlayingViewMode.split;
  const lyricsOnly = NowPlayingViewMode.lyricsOnly;
  const coverOnly = NowPlayingViewMode.coverOnly;

  group('nextViewMode', () {
    const table = {split: lyricsOnly, lyricsOnly: coverOnly, coverOnly: split};
    for (final MapEntry(key: shown, value: expected) in table.entries) {
      test('after $shown comes $expected', () {
        expect(nextViewMode(shown), expected);
      });
    }
  });

  group('nowPlayingLyricsAvailableProvider', () {
    const sung = Track(uri: '/m/sung.flac', title: 'Sung');
    const plain = Track(uri: '/m/plain.flac', title: 'Plain');
    const other = Track(uri: '/m/other.flac', title: 'Other');
    late FakeLrcSidecarReader sidecar;
    late ProviderContainer container;
    late ProviderSubscription<bool> sub;

    setUp(() async {
      sidecar = FakeLrcSidecarReader()
        ..byPath['/m/sung.flac'] = '[00:00.00]First'
        ..byPath['/m/other.flac'] = '[00:00.00]Other';
      container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          embeddedLyricsReaderProvider.overrideWithValue(
            FakeEmbeddedLyricsReader(),
          ),
          lrcSidecarReaderProvider.overrideWithValue(sidecar),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerServiceProvider.notifier).openTracks([
        sung,
        plain,
        other,
      ]);
      // Listening keeps the autoDispose provider alive between reads.
      sub = container.listen(nowPlayingLyricsAvailableProvider, (_, _) {});
      addTearDown(sub.close);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('is true for a track with lyrics', () async {
      await settle();
      expect(sub.read(), isTrue);
    });

    test('is false for a track without lyrics', () async {
      await container.read(playerServiceProvider.notifier).next();
      await settle();
      expect(sub.read(), isFalse);
    });

    test('keeps the previous answer while the next track reads', () async {
      await settle();
      expect(sub.read(), isTrue);
      final gate = Completer<void>();
      sidecar.gates['/m/plain.flac'] = gate;

      await container.read(playerServiceProvider.notifier).next();
      await settle();
      expect(sub.read(), isTrue);

      gate.complete();
      await settle();
      await settle();
      expect(sub.read(), isFalse);
    });
  });
}
