import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/playing_track_lyrics_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/status_test_rig.dart';
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

  group('nowPlayingLyricsAvailableProvider with online lookups', () {
    test(
      'is false while a search runs and true once it finds lyrics',
      () async {
        final rig = await createStatusRig();
        rig.sidecar.byPath['/m/a.flac'] = '[00:00.00]Own';
        final gate = rig.fake.gate = Completer<void>();
        rig.fake.lookupResult = fakeCandidate();
        final sub = rig.container.listen(
          nowPlayingLyricsAvailableProvider,
          (_, _) {},
        );
        addTearDown(sub.close);
        await rig.play([fakeSong('/m/a.flac'), fakeSong('/m/b.flac')]);
        await rig.until(() => sub.read());

        await rig.player.next();
        await rig.until(() => rig.status is LyricsSearching);
        expect(sub.read(), isFalse);

        gate.complete();
        await rig.until(() => rig.status is LyricsFound);
        expect(sub.read(), isTrue);
      },
    );

    test('the derived lyrics are loading while searching', () async {
      final rig = await createStatusRig();
      final gate = rig.fake.gate = Completer<void>();
      rig.fake.lookupResult = fakeCandidate();
      final sub = rig.container.listen(playingTrackLyricsProvider, (_, _) {});
      addTearDown(sub.close);
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.fake.lookupCalls == 1);
      expect(sub.read().isLoading, isTrue);

      gate.complete();
      await rig.until(() => sub.read().value != null);
      expect(sub.read().value!.uri, '/m/a.flac');
    });
  });
}
