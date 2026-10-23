import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/lyrics_view.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/fake_lyrics_readers.dart';
import '../../../core/player/fake_audio_backend.dart';

const _withLyrics = Track(uri: '/m/sung.flac', title: 'Sung', artist: 'A');
const _without = Track(uri: '/m/instrumental.flac', title: 'Instrumental');
const _alsoSung = Track(uri: '/m/also.flac', title: 'Also sung');

void main() {
  late FakeEmbeddedLyricsReader embedded;
  late FakeLrcSidecarReader sidecar;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  final lyricsOnly = find.byTooltip('Lyrics only');
  final lyricsTab = find.byTooltip('Lyrics');

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    List<Track> tracks = const [_withLyrics, _without],
    bool open = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    embedded = FakeEmbeddedLyricsReader();
    sidecar = FakeLrcSidecarReader()
      ..byPath['/m/sung.flac'] = '[00:00.00]First words\n[00:05.00]More words';
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(embedded),
        lrcSidecarReaderProvider.overrideWithValue(sidecar),
      ],
    );
    addTearDown(container.dispose);
    await player().openTracks(tracks);
    if (open) container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NowPlayingOverlay(behind: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is read while Now Playing is closed', (tester) async {
    await pump(tester, open: false);
    expect(sidecar.reads, isEmpty);
    expect(embedded.reads, isEmpty);
  });

  testWidgets('wide: the lyrics take the right half', (tester) async {
    await pump(tester);
    expect(find.byType(LyricsView), findsOneWidget);
    expect(lyricsOnly, findsOneWidget);
    expect(tester.getCenter(find.text('First words')).dx, greaterThan(640));
  });

  testWidgets('wide: a track without lyrics keeps the old layout', (
    tester,
  ) async {
    await pump(tester, tracks: const [_without]);
    expect(find.byType(LyricsView), findsNothing);
    expect(lyricsOnly, findsNothing);
  });

  testWidgets('moving to a track without lyrics removes the slot', (
    tester,
  ) async {
    await pump(tester);
    await player().next();
    await tester.pumpAndSettle();
    expect(find.byType(LyricsView), findsNothing);
    expect(find.text('First words'), findsNothing);
  });

  testWidgets('while the next track loads, the slot stays but shows nothing '
      'of the previous track', (tester) async {
    await pump(tester, tracks: const [_withLyrics, _alsoSung]);
    final gate = Completer<void>();
    sidecar
      ..byPath['/m/also.flac'] = '[00:00.00]Other words'
      ..gates['/m/also.flac'] = gate;

    await player().next();
    await tester.pump();
    expect(find.byType(LyricsView), findsOneWidget);
    expect(find.text('First words'), findsNothing);
    expect(find.text('Other words'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Other words'), findsOneWidget);
  });

  testWidgets('narrow: a lyrics page right of the track', (tester) async {
    await pump(tester, size: const Size(400, 800));
    expect(lyricsTab, findsOneWidget);
    expect(find.text('First words'), findsNothing);

    await tester.tap(lyricsTab);
    await tester.pumpAndSettle();
    expect(find.text('First words'), findsOneWidget);
  });

  testWidgets('narrow: no lyrics tab without lyrics', (tester) async {
    await pump(tester, size: const Size(400, 800), tracks: const [_without]);
    expect(lyricsTab, findsNothing);
  });

  testWidgets('narrow: losing the lyrics while on their page shows the track', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 800));
    await tester.tap(lyricsTab);
    await tester.pumpAndSettle();

    await player().next();
    await tester.pumpAndSettle();
    expect(lyricsTab, findsNothing);
    expect(find.text('Instrumental'), findsWidgets);
  });
}
