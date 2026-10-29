import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/lyrics_view.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_only_body.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/features/player/now_playing/now_playing_side_tab.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/fake_lyrics_readers.dart';
import '../../../core/player/fake_audio_backend.dart';
import 'fake_playing_lyrics_status.dart';

const _withLyrics = Track(uri: '/m/sung.flac', title: 'Sung', artist: 'A');
const _without = Track(uri: '/m/instrumental.flac', title: 'Instrumental');
const _alsoSung = Track(uri: '/m/also.flac', title: 'Also sung');

void main() {
  late FakeEmbeddedLyricsReader embedded;
  late FakeLrcSidecarReader sidecar;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  final lyricsTab = find.byTooltip('Lyrics');
  final splitLyricsTab = find.widgetWithText(Tab, 'Lyrics');

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    List<Track> tracks = const [_withLyrics, _without],
    bool open = true,
    List<Override> overrides = const [],
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
        ...overrides,
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

  testWidgets('wide: the lyrics are in the Split Lyrics tab', (tester) async {
    await pump(tester);
    expect(find.byType(LyricsView), findsOneWidget);
    expect(splitLyricsTab, findsOneWidget);
    expect(find.widgetWithText(Tab, 'Now playing'), findsOneWidget);
    // Right of the track column, which takes 42% of the width.
    expect(
      tester.getCenter(find.text('First words')).dx,
      greaterThan(1280 * 0.42),
    );
    // The queue is behind the other tab, not built.
    expect(find.byType(QueuePanel), findsNothing);
  });

  testWidgets('wide: a track without lyrics has both tabs and the empty '
      'state', (tester) async {
    await pump(tester, tracks: const [_without]);
    expect(find.byType(LyricsView), findsOneWidget);
    expect(splitLyricsTab, findsOneWidget);
    expect(find.widgetWithText(Tab, 'Now playing'), findsOneWidget);
    expect(find.text('No lyrics for this song'), findsOneWidget);
    expect(find.byType(QueuePanel), findsNothing);
  });

  final queueTab = find.widgetWithText(Tab, 'Now playing');

  testWidgets('wide: the Queue tab stays chosen on a track change', (
    tester,
  ) async {
    await pump(tester, tracks: const [_withLyrics, _alsoSung]);
    sidecar.byPath['/m/also.flac'] = '[00:00.00]Other words';
    await tester.tap(queueTab);
    await tester.pumpAndSettle();

    await player().next();
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('Other words'), findsNothing);
    expect(splitLyricsTab, findsOneWidget);
    expect(queueTab, findsOneWidget);
  });

  testWidgets('wide: the Queue tab stays chosen through a track without '
      'lyrics', (tester) async {
    await pump(tester, tracks: const [_withLyrics, _without, _alsoSung]);
    sidecar.byPath['/m/also.flac'] = '[00:00.00]Other words';
    await tester.tap(queueTab);
    await tester.pumpAndSettle();

    await player().next();
    await tester.pumpAndSettle();
    expect(splitLyricsTab, findsOneWidget);
    expect(find.byType(QueuePanel), findsOneWidget);

    await player().next();
    await tester.pumpAndSettle();
    expect(splitLyricsTab, findsOneWidget);
    expect(queueTab, findsOneWidget);
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('Other words'), findsNothing);
  });

  testWidgets('wide: the Lyrics tab stays through a track without lyrics', (
    tester,
  ) async {
    await pump(tester);

    await player().next();
    await tester.pumpAndSettle();
    expect(splitLyricsTab, findsOneWidget);
    expect(find.byType(QueuePanel), findsNothing);
    expect(find.text('No lyrics for this song'), findsOneWidget);

    await player().previous();
    await tester.pumpAndSettle();
    expect(find.text('First words'), findsOneWidget);
    expect(find.byType(QueuePanel), findsNothing);
  });

  testWidgets('moving to a track without lyrics keeps the slot and shows the '
      'empty state', (tester) async {
    await pump(tester);
    await player().next();
    await tester.pumpAndSettle();
    expect(find.byType(LyricsView), findsOneWidget);
    expect(find.text('First words'), findsNothing);
    expect(find.text('No lyrics for this song'), findsOneWidget);
    expect(splitLyricsTab, findsOneWidget);
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

  testWidgets('narrow: lyrics tab without lyrics', (tester) async {
    await pump(tester, size: const Size(400, 800), tracks: const [_without]);
    expect(lyricsTab, findsOneWidget);
    await tester.tap(lyricsTab);
    await tester.pumpAndSettle();
    expect(find.text('No lyrics for this song'), findsOneWidget);
  });

  testWidgets('narrow: losing the lyrics while on their page stays there', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 800));
    await tester.tap(lyricsTab);
    await tester.pumpAndSettle();

    await player().next();
    await tester.pumpAndSettle();
    expect(lyricsTab, findsOneWidget);
    expect(find.text('No lyrics for this song'), findsOneWidget);
  });

  group('layout stays put across track changes', () {
    // Lyrics, none, loading (gated), lyrics.
    Future<void> walk(
      WidgetTester tester,
      void Function() check, {
      required Future<void> Function() before,
    }) async {
      await before();
      final gate = Completer<void>();
      sidecar
        ..byPath['/m/also.flac'] = '[00:00.00]Other words'
        ..gates['/m/gated.flac'] = gate
        ..byPath['/m/gated.flac'] = '[00:00.00]Gated words';
      check();
      await player().next(); // none
      await tester.pumpAndSettle();
      check();
      await player().next(); // loading
      await tester.pump();
      check();
      gate.complete();
      await tester.pumpAndSettle();
      check();
      await player().next(); // lyrics
      await tester.pumpAndSettle();
      check();
    }

    const tracks = [
      _withLyrics,
      _without,
      Track(uri: '/m/gated.flac', title: 'Gated'),
      _alsoSung,
    ];

    testWidgets('Split keeps the Queue tab', (tester) async {
      await pump(tester, tracks: tracks);
      await walk(
        tester,
        () {
          expect(find.byType(QueuePanel), findsOneWidget);
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
            1,
          );
        },
        before: () async {
          await tester.tap(queueTab);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('Lyrics only keeps its body and mode', (tester) async {
      await pump(tester, tracks: tracks);
      await walk(
        tester,
        () {
          expect(find.byType(NowPlayingLyricsOnlyBody), findsOneWidget);
          expect(
            container.read(nowPlayingViewModeProvider),
            NowPlayingViewMode.lyricsOnly,
          );
        },
        before: () async {
          container
              .read(nowPlayingViewModeProvider.notifier)
              .choose(NowPlayingViewMode.lyricsOnly);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('narrow keeps the lyrics page', (tester) async {
      await pump(tester, size: const Size(400, 800), tracks: tracks);
      await walk(
        tester,
        () {
          expect(lyricsTab, findsOneWidget);
          final view = tester.widget<PageView>(find.byType(PageView));
          expect(view.controller!.page, 2);
        },
        before: () async {
          await tester.tap(lyricsTab);
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('layout stays put across online lyrics states', () {
    const uri = '/m/sung.flac';
    const origin = OnlineLyricsOrigin(
      providerId: 'lrclib',
      remoteId: '1',
      pinned: false,
    );

    /// Local lyrics, none, searching, found online, error, local again; the
    /// status moves by hand, the layout [check] must not notice.
    Future<void> walk(
      WidgetTester tester,
      FakePlayingLyricsStatus status,
      void Function() check, {
      required Future<void> Function() before,
      void Function(PlayingLyricsStatus step)? checkStep,
    }) async {
      await before();
      final steps = <PlayingLyricsStatus>[
        LyricsFound(uri, fakeSyncedLyrics()),
        const LyricsNone(uri, LyricsNoneReason.noLyrics),
        const LyricsSearching(uri, 'lrclib'),
        LyricsFound(uri, fakePlainLyrics('Online words'), origin: origin),
        const LyricsNone(
          uri,
          LyricsNoneReason.error,
          failure: LyricsFetchKind.network,
        ),
        LyricsFound(uri, fakeSyncedLyrics()),
      ];
      for (final step in steps) {
        status.emit(step);
        // A search pulses forever, so step instead of settling.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        check();
        checkStep?.call(step);
      }
    }

    FakePlayingLyricsStatus fresh() =>
        FakePlayingLyricsStatus(LyricsFound(uri, fakeSyncedLyrics()));

    testWidgets('Split keeps the Queue tab', (tester) async {
      final status = fresh();
      await pump(
        tester,
        overrides: [playingLyricsStatusProvider.overrideWith(() => status)],
      );
      await walk(
        tester,
        status,
        () {
          expect(find.byType(QueuePanel), findsOneWidget);
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
            1,
          );
        },
        before: () async {
          await tester.tap(queueTab);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('Split with the Lyrics tab shows every state in it', (
      tester,
    ) async {
      final status = fresh();
      await pump(
        tester,
        overrides: [playingLyricsStatusProvider.overrideWith(() => status)],
      );
      await walk(
        tester,
        status,
        () {
          expect(find.byType(QueuePanel), findsNothing);
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
            0,
          );
        },
        before: () async {},
        checkStep: (step) {
          final text = switch (step) {
            LyricsFound(origin: null) => 'First words',
            LyricsFound() => 'Online words',
            LyricsSearching() => 'Searching LRCLIB…',
            LyricsNone(reason: LyricsNoneReason.error) =>
              "Couldn't reach LRCLIB",
            _ => 'No lyrics for this song',
          };
          expect(find.text(text), findsOneWidget, reason: '$step');
        },
      );
    });

    testWidgets('Lyrics only keeps its body and mode', (tester) async {
      final status = fresh();
      await pump(
        tester,
        overrides: [playingLyricsStatusProvider.overrideWith(() => status)],
      );
      await walk(
        tester,
        status,
        () {
          expect(find.byType(NowPlayingLyricsOnlyBody), findsOneWidget);
          expect(
            container.read(nowPlayingViewModeProvider),
            NowPlayingViewMode.lyricsOnly,
          );
        },
        before: () async {
          container
              .read(nowPlayingViewModeProvider.notifier)
              .choose(NowPlayingViewMode.lyricsOnly);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('narrow keeps the lyrics page', (tester) async {
      final status = fresh();
      await pump(
        tester,
        size: const Size(400, 800),
        overrides: [playingLyricsStatusProvider.overrideWith(() => status)],
      );
      await walk(
        tester,
        status,
        () {
          expect(lyricsTab, findsOneWidget);
          final view = tester.widget<PageView>(find.byType(PageView));
          expect(view.controller!.page, 2);
        },
        before: () async {
          await tester.tap(lyricsTab);
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('the side tab for the app session', () {
    testWidgets('closing and reopening keeps the Queue tab', (tester) async {
      await pump(tester);
      expect(
        container.read(nowPlayingSideTabProvider),
        NowPlayingSideTab.lyrics,
      );
      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      container.read(nowPlayingOpenProvider.notifier).close();
      await tester.pumpAndSettle();
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('Split, Cover only, Split keeps the Queue tab', (tester) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();
      final modes = container.read(nowPlayingViewModeProvider.notifier);

      modes.choose(NowPlayingViewMode.coverOnly);
      await tester.pumpAndSettle();
      modes.choose(NowPlayingViewMode.split);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('wide, narrow, wide keeps the Queue tab and narrow opens on '
        'the track page', (tester) async {
      await pump(tester);
      await tester.tap(queueTab);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      final view = tester.widget<PageView>(find.byType(PageView));
      expect(view.controller!.page, 1);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsOneWidget);
    });
  });
}
