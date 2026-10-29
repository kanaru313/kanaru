import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_cover_only_body.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_only_body.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/player/fake_audio_backend.dart';
import 'fake_translation_controller.dart';

const _sung = Track(uri: '/m/sung.flac', title: 'Sung', artist: 'A');
const _plain = Track(uri: '/m/instrumental.flac', title: 'Plain', artist: 'B');

/// Counts how often it is mounted and unmounted.
class _Probe extends StatefulWidget {
  const _Probe(this.log);

  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init');
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late FakeLrcSidecarReader sidecar;
  late ProviderContainer container;

  /// Settings and extra overrides the next container starts with.
  var startSettings = const AppSettings();
  var extraOverrides = <Override>[];

  PlayerService player() => container.read(playerServiceProvider.notifier);
  NowPlayingViewMode chosen() => container.read(nowPlayingViewModeProvider);
  final splitBody = find.byType(NowPlayingTrackColumn);
  final lyricsBody = find.byType(NowPlayingLyricsOnlyBody);
  final coverBody = find.byType(NowPlayingCoverOnlyBody);
  final toSplit = find.byTooltip('Split view');
  final toLyrics = find.byTooltip('Lyrics only');
  final toCover = find.byTooltip('Cover only');

  void setUpWindow(
    WidgetTester tester, {
    required Size size,
    required bool reduceMotion,
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Widget app(Widget home) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  void makeContainer() {
    sidecar = FakeLrcSidecarReader()
      ..byPath['/m/sung.flac'] = '[00:00.00]First words\n[00:05.00]More words';
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(
          FakeEmbeddedLyricsReader(),
        ),
        lrcSidecarReaderProvider.overrideWithValue(sidecar),
        initialSettingsProvider.overrideWithValue(startSettings),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
  }

  /// The real overlay, so the lyrics state comes from the lyrics read.
  Future<void> pumpOverlay(
    WidgetTester tester, {
    List<Track> tracks = const [_sung, _plain],
    Size size = const Size(1280, 800),
    bool reduceMotion = true,
    NowPlayingViewMode? mode,
  }) async {
    setUpWindow(tester, size: size, reduceMotion: reduceMotion);
    makeContainer();
    if (mode != null) {
      container.read(nowPlayingViewModeProvider.notifier).choose(mode);
    }
    await player().openTracks(tracks);
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpWidget(
      app(const NowPlayingOverlay(behind: SizedBox.expand())),
    );
    await tester.pumpAndSettle();
  }

  /// The screen with a fixed lyrics widget.
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Track> tracks = const [_sung],
    Widget? lyrics = const SizedBox.expand(),
    Size size = const Size(1280, 800),
    bool reduceMotion = true,
    NowPlayingViewMode? mode,
  }) async {
    setUpWindow(tester, size: size, reduceMotion: reduceMotion);
    makeContainer();
    if (mode != null) {
      container.read(nowPlayingViewModeProvider.notifier).choose(mode);
    }
    if (tracks.isNotEmpty) await player().openTracks(tracks);
    await tester.pumpWidget(app(NowPlayingScreen(lyrics: lyrics)));
    await tester.pumpAndSettle();
  }

  TranslationPrefs translation() =>
      container.read(settingsProvider).translation;

  Future<void> pressT(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
  }

  Future<void> pressV(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.pumpAndSettle();
  }

  Future<void> pressL(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pumpAndSettle();
  }

  group('the button', () {
    testWidgets('its icon shows the mode and its tooltip names the next', (
      tester,
    ) async {
      await pumpOverlay(tester);
      expect(find.byIcon(AppIcons.viewSplit), findsOneWidget);
      expect(toLyrics, findsOneWidget);

      await tester.tap(toLyrics);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(NowPlayingViewModeButton),
          matching: find.byIcon(AppIcons.lyrics),
        ),
        findsOneWidget,
      );
      expect(toCover, findsOneWidget);

      await tester.tap(toCover);
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.viewCover), findsOneWidget);
      expect(toSplit, findsOneWidget);
    });

    testWidgets('presses cycle Split, Lyrics only, Cover only', (tester) async {
      await pumpOverlay(tester);
      expect(splitBody, findsOneWidget);

      await tester.tap(toLyrics);
      await tester.pumpAndSettle();
      expect(lyricsBody, findsOneWidget);
      expect(splitBody, findsNothing);

      await tester.tap(toCover);
      await tester.pumpAndSettle();
      expect(coverBody, findsOneWidget);
      expect(lyricsBody, findsNothing);

      await tester.tap(toSplit);
      await tester.pumpAndSettle();
      expect(splitBody, findsOneWidget);
      expect(coverBody, findsNothing);
    });

    testWidgets('without lyrics the cycle still has Lyrics only', (
      tester,
    ) async {
      await pumpOverlay(tester, tracks: const [_plain]);
      expect(toLyrics, findsOneWidget);

      await tester.tap(toLyrics);
      await tester.pumpAndSettle();
      expect(lyricsBody, findsOneWidget);

      await tester.tap(toCover);
      await tester.pumpAndSettle();
      expect(coverBody, findsOneWidget);

      await tester.tap(toSplit);
      await tester.pumpAndSettle();
      expect(splitBody, findsOneWidget);
    });

    testWidgets('a click on the strip cover chooses Split', (tester) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.lyricsOnly);
      expect(lyricsBody, findsOneWidget);

      await tester.tap(toSplit);
      await tester.pumpAndSettle();

      expect(splitBody, findsOneWidget);
      expect(chosen(), NowPlayingViewMode.split);
    });

    testWidgets('closing and reopening keeps the mode', (tester) async {
      await pumpOverlay(tester);
      await tester.tap(toLyrics);
      await tester.pumpAndSettle();
      await tester.tap(toCover);
      await tester.pumpAndSettle();

      container.read(nowPlayingOpenProvider.notifier).close();
      await tester.pumpAndSettle();
      expect(coverBody, findsNothing);
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      expect(coverBody, findsOneWidget);
    });

    testWidgets('narrow windows have no mode button', (tester) async {
      await pumpScreen(tester, size: const Size(600, 900));
      expect(toLyrics, findsNothing);
      expect(toCover, findsNothing);
      expect(find.byIcon(AppIcons.viewSplit), findsNothing);
    });
  });

  group('lyrics coming and going', () {
    testWidgets('Lyrics only stays on a track without lyrics', (tester) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.lyricsOnly);
      expect(lyricsBody, findsOneWidget);

      await player().next();
      await tester.pumpAndSettle();
      expect(lyricsBody, findsOneWidget);
      expect(coverBody, findsNothing);
      expect(splitBody, findsNothing);
      expect(chosen(), NowPlayingViewMode.lyricsOnly);
      expect(toCover, findsOneWidget);

      await player().previous();
      await tester.pumpAndSettle();
      expect(lyricsBody, findsOneWidget);
      expect(find.text('First words'), findsOneWidget);
    });

    testWidgets('reopening in Lyrics only never shows another body', (
      tester,
    ) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.lyricsOnly);
      container.read(nowPlayingOpenProvider.notifier).close();
      await tester.pumpAndSettle();

      final gate = Completer<void>();
      sidecar.gates['/m/sung.flac'] = gate;
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        expect(splitBody, findsNothing);
        expect(coverBody, findsNothing);
        expect(lyricsBody, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      }

      gate.complete();
      await tester.pump();
      await tester.pump();
      // The answer arrives without a second body fading out.
      expect(lyricsBody, findsOneWidget);
      expect(splitBody, findsNothing);
      expect(coverBody, findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('First words'), findsOneWidget);
    });

    testWidgets(
      'reopening in Lyrics only on a track without lyrics shows the empty '
      'state',
      (tester) async {
        await pumpOverlay(
          tester,
          tracks: const [_plain],
          mode: NowPlayingViewMode.lyricsOnly,
        );
        expect(lyricsBody, findsOneWidget);
        container.read(nowPlayingOpenProvider.notifier).close();
        await tester.pumpAndSettle();

        final gate = Completer<void>();
        sidecar.gates['/m/instrumental.flac'] = gate;
        container.read(nowPlayingOpenProvider.notifier).open();
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          expect(splitBody, findsNothing);
          expect(lyricsBody, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 100));
        }

        gate.complete();
        await tester.pumpAndSettle();
        expect(lyricsBody, findsOneWidget);
        expect(coverBody, findsNothing);
        expect(splitBody, findsNothing);
        expect(find.text('No lyrics for this song'), findsOneWidget);
      },
    );

    testWidgets('a track change never changes the mode', (tester) async {
      await pumpOverlay(
        tester,
        mode: NowPlayingViewMode.lyricsOnly,
        reduceMotion: false,
      );
      for (final step in [player().next, player().previous, player().next]) {
        await step();
        // No fade frames: the one body is there on every frame.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          expect(lyricsBody, findsOneWidget);
          expect(coverBody, findsNothing);
          expect(splitBody, findsNothing);
          expect(chosen(), NowPlayingViewMode.lyricsOnly);
        }
      }
    });
  });

  group('the V key', () {
    testWidgets('cycles the mode', (tester) async {
      await pumpOverlay(tester);
      await pressV(tester);
      expect(lyricsBody, findsOneWidget);
      await pressV(tester);
      expect(coverBody, findsOneWidget);
      await pressV(tester);
      expect(splitBody, findsOneWidget);
    });

    testWidgets('typed in the queue filter goes to the field', (tester) async {
      await pumpOverlay(tester, tracks: const [_plain]);
      await tester.tap(find.widgetWithText(Tab, 'Now playing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(EditableText));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(splitBody, findsOneWidget);
      expect(chosen(), NowPlayingViewMode.split);
    });

    testWidgets('does nothing while the sleep timer menu is open', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await tester.tap(find.byTooltip('Sleep timer'));
      await tester.pumpAndSettle();

      await pressV(tester);

      expect(chosen(), NowPlayingViewMode.split);
      expect(splitBody, findsOneWidget);
    });

    testWidgets('ignores Ctrl+V and Shift+V', (tester) async {
      await pumpOverlay(tester);
      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
      }
      expect(chosen(), NowPlayingViewMode.split);
      expect(splitBody, findsOneWidget);
    });

    testWidgets('is ignored in the narrow layout', (tester) async {
      await pumpScreen(tester, size: const Size(600, 900));
      await pressV(tester);
      expect(chosen(), NowPlayingViewMode.split);
    });
  });

  group('the L key', () {
    final sourceMenu = find.text('Lyrics for this song');

    setUp(() {
      startSettings = const AppSettings();
      extraOverrides = [];
    });

    testWidgets('opens the lyrics source menu and leaves the mode alone', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await pressL(tester);
      expect(sourceMenu, findsOneWidget);
      expect(chosen(), NowPlayingViewMode.split);
      expect(splitBody, findsOneWidget);
    });

    testWidgets('opens it in Lyrics only too', (tester) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.lyricsOnly);
      await pressL(tester);
      expect(sourceMenu, findsOneWidget);
    });

    testWidgets('opens it in the narrow layout', (tester) async {
      await pumpScreen(tester, size: const Size(600, 900));
      await pressL(tester);
      expect(sourceMenu, findsOneWidget);
    });

    testWidgets('while the menu is open, L, V and T are for the menu', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await pressL(tester);
      await pressV(tester);
      await pressT(tester);
      expect(chosen(), NowPlayingViewMode.split);
      expect(translation().show, isFalse);
      expect(sourceMenu, findsOneWidget);
    });

    testWidgets('does nothing in Cover only', (tester) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.coverOnly);
      await pressL(tester);
      expect(sourceMenu, findsNothing);
      expect(chosen(), NowPlayingViewMode.coverOnly);
    });

    testWidgets('does nothing when no pill is there', (tester) async {
      await pumpScreen(tester, tracks: const []);
      expect(find.byType(LyricsSourceButton), findsOneWidget);
      await pressL(tester);
      expect(sourceMenu, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('typed in the queue filter goes to the field', (tester) async {
      await pumpOverlay(tester, tracks: const [_plain]);
      await tester.tap(find.widgetWithText(Tab, 'Now playing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(EditableText));

      await pressL(tester);

      expect(sourceMenu, findsNothing);
    });

    testWidgets('ignores Ctrl+L and Shift+L', (tester) async {
      await pumpOverlay(tester);
      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
      }
      expect(sourceMenu, findsNothing);
    });

    testWidgets('does nothing while the sleep timer menu is open', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await tester.tap(find.byTooltip('Sleep timer'));
      await tester.pumpAndSettle();

      await pressL(tester);

      expect(sourceMenu, findsNothing);
    });

    testWidgets('narrow: an open translation menu keeps L and T out', (
      tester,
    ) async {
      startSettings = const AppSettings(
        translation: TranslationPrefs(
          noticeAcknowledged: {LyricsTranslationService.google},
        ),
      );
      extraOverrides = [
        lyricsTranslationProvider.overrideWith2(
          (_) =>
              FakeTranslationController(TranslationOff(fakeTranslationInfo())),
        ),
      ];
      await pumpScreen(tester, size: const Size(600, 900));
      await tester.tap(find.byTooltip('Lyrics translation'));
      await tester.pumpAndSettle();
      expect(find.text('Show translation'), findsOneWidget);

      await pressL(tester);
      await pressT(tester);

      expect(sourceMenu, findsNothing);
      expect(translation().show, isFalse);
    });

    testWidgets('narrow: an open source menu keeps T out', (tester) async {
      startSettings = const AppSettings(
        translation: TranslationPrefs(
          noticeAcknowledged: {LyricsTranslationService.google},
        ),
      );
      await pumpScreen(tester, size: const Size(600, 900));
      await pressL(tester);
      expect(sourceMenu, findsOneWidget);

      await pressT(tester);

      expect(translation().show, isFalse);
    });
  });

  group('the T key', () {
    const accepted = AppSettings(
      translation: TranslationPrefs(
        noticeAcknowledged: {LyricsTranslationService.google},
      ),
    );

    setUp(() {
      startSettings = accepted;
      extraOverrides = [];
    });

    testWidgets('toggles translation in the wide layout', (tester) async {
      await pumpOverlay(tester);
      await pressT(tester);
      expect(translation().show, isTrue);
      await pressT(tester);
      expect(translation().show, isFalse);
    });

    testWidgets('toggles translation in the narrow layout', (tester) async {
      await pumpScreen(tester, size: const Size(600, 900));
      await pressT(tester);
      expect(translation().show, isTrue);
      await pressT(tester);
      expect(translation().show, isFalse);
    });

    testWidgets('the first time asks; Cancel keeps it off', (tester) async {
      startSettings = const AppSettings();
      await pumpOverlay(tester);

      await pressT(tester);
      expect(find.text('Lyrics will be sent to Google'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(translation().show, isFalse);
      expect(translation().noticeAcknowledged, isEmpty);
    });

    testWidgets('Continue accepts and turns it on; later presses are silent', (
      tester,
    ) async {
      startSettings = const AppSettings();
      await pumpOverlay(tester);

      await pressT(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(translation().show, isTrue);
      expect(translation().noticeAcknowledged, {
        LyricsTranslationService.google,
      });

      await pressT(tester);
      await pressT(tester);
      expect(find.textContaining('will be sent'), findsNothing);
      expect(translation().show, isTrue);
    });

    testWidgets('turning on needs lyrics; turning off does not', (
      tester,
    ) async {
      await pumpOverlay(tester, tracks: const [_plain]);
      await pressT(tester);
      expect(translation().show, isFalse);
      expect(find.textContaining('will be sent'), findsNothing);

      container
          .read(settingsProvider.notifier)
          .setTranslation(translation().copyWith(show: true));
      await tester.pumpAndSettle();
      await pressT(tester);
      expect(translation().show, isFalse);
    });

    testWidgets('does nothing in Cover only', (tester) async {
      await pumpOverlay(tester, mode: NowPlayingViewMode.coverOnly);

      await pressT(tester);

      expect(translation().show, isFalse);
      expect(find.textContaining('will be sent'), findsNothing);
    });

    testWidgets('typed in the queue filter goes to the field', (tester) async {
      await pumpOverlay(tester, tracks: const [_plain]);
      await tester.tap(find.widgetWithText(Tab, 'Now playing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(EditableText));

      await pressT(tester);

      expect(translation().show, isFalse);
    });

    testWidgets('ignores Ctrl+T and Shift+T', (tester) async {
      await pumpOverlay(tester);
      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
      }
      expect(translation().show, isFalse);
    });

    testWidgets('does nothing while the sleep timer menu is open', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await tester.tap(find.byTooltip('Sleep timer'));
      await tester.pumpAndSettle();

      await pressT(tester);

      expect(translation().show, isFalse);
    });

    testWidgets('does nothing while the translation menu is open', (
      tester,
    ) async {
      // A fresh notifier each time: the button's provider is recreated when
      // the header is rebuilt.
      extraOverrides = [
        lyricsTranslationProvider.overrideWith2(
          (_) =>
              FakeTranslationController(TranslationOff(fakeTranslationInfo())),
        ),
      ];
      await pumpOverlay(tester);
      await tester.tap(find.byTooltip('Lyrics translation'));
      await tester.pumpAndSettle();
      expect(find.text('Show translation'), findsOneWidget);

      await pressT(tester);

      expect(translation().show, isFalse);
    });
  });

  group('the switch', () {
    testWidgets('both bodies exist halfway, one after 300 ms', (tester) async {
      await pumpOverlay(tester, reduceMotion: false);

      await tester.tap(toLyrics);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(splitBody, findsOneWidget);
      expect(lyricsBody, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 160));
      expect(splitBody, findsNothing);
      expect(lyricsBody, findsOneWidget);
    });

    testWidgets('under reduced motion it takes one frame', (tester) async {
      await pumpOverlay(tester);

      await tester.tap(toLyrics);
      await tester.pump();

      expect(splitBody, findsNothing);
      expect(lyricsBody, findsOneWidget);
    });

    testWidgets('the outgoing body is not remounted while it fades', (
      tester,
    ) async {
      final log = <String>[];
      await pumpScreen(
        tester,
        lyrics: _Probe(log),
        mode: NowPlayingViewMode.lyricsOnly,
        reduceMotion: false,
      );
      expect(log, ['init']);

      await tester.tap(toCover);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, ['init']);
      expect(coverBody, findsOneWidget);
      expect(lyricsBody, findsOneWidget);

      await tester.pumpAndSettle();
      expect(log, ['init', 'dispose']);
    });
  });
}
