import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header_pills.dart'
    show nowPlayingPillGap, nowPlayingPillLabelRooms;
import 'package:kanaru/features/player/playback_controls.dart'
    show ShuffleButton;
import 'package:kanaru/features/player/now_playing/now_playing_title_bar.dart';
import 'package:kanaru/features/player/repeat/repeat_button.dart';
import 'package:kanaru/features/player/volume_button.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/fake_audio_backend.dart';
import '../../core/player/manual_fade_clock.dart';
import 'fake_translation_controller.dart';
import 'lyrics/fake_playing_lyrics_resolution.dart';
import 'lyrics/fake_playing_lyrics_status.dart' show fakeSyncedLyrics;

/// Marks what the header wrapped in its drag exclusion.
class _Excluded extends StatelessWidget {
  const _Excluded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

void main() {
  late ProviderContainer container;
  late ValueNotifier<bool> floating;
  var closed = 0;

  /// Width of the window buttons and their right padding in the shell.
  const windowButtons = 152.0 + 16;

  /// The header in a row like the shell's title bar builds it: the header
  /// first, then room for the window buttons.
  Future<void> pump(
    WidgetTester tester, {
    double width = 1280,
    bool windowButtons = false,
    double textScale = 1,
    Widget? modeButton,
    bool exclude = false,
    bool showTranslate = false,
    bool translateEnabled = true,
    Locale locale = const Locale('en'),
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        // A clock moved by hand, so a running timer leaves no real one.
        playbackFadeClockProvider.overrideWithValue(ManualFadeClock().clock),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    floating = ValueNotifier<bool>(false);
    addTearDown(floating.dispose);
    closed = 0;
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/a.mp3'),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  Expanded(
                    child: NowPlayingHeader(
                      onClose: () => closed++,
                      excludeFromDrag: exclude
                          ? (button) => _Excluded(child: button)
                          : noDragExclusion,
                      floatingOpen: floating,
                      hasWindowButtons: windowButtons,
                      modeButton: modeButton,
                      showTranslate: showTranslate,
                      translateEnabled: translateEnabled,
                    ),
                  ),
                  if (windowButtons)
                    const SizedBox(
                      width: 168,
                      child: Placeholder(strokeWidth: 0),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double centerX(WidgetTester tester, String tooltip) =>
      tester.getCenter(find.byTooltip(tooltip)).dx;

  testWidgets('has its buttons in order and no queue button', (tester) async {
    await pump(tester);

    final order = [
      'Close Now Playing',
      'Add to favorites',
      'Add to playlist',
      'Shuffle',
      'Stop after the last song',
      'Sleep timer',
      'Mute',
    ].map((tooltip) => centerX(tester, tooltip)).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(find.byTooltip('Show now playing list'), findsNothing);
    expect(tester.getSize(find.byType(NowPlayingHeader)).height, 64);
  });

  testWidgets('the close button closes', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Close Now Playing'));
    expect(closed, 1);
  });

  testWidgets('the mode slot sits right of close, before the song actions', (
    tester,
  ) async {
    await pump(
      tester,
      modeButton: const SizedBox(key: Key('mode'), width: 48, height: 48),
    );

    final mode = tester.getCenter(find.byKey(const Key('mode'))).dx;
    expect(mode, greaterThan(centerX(tester, 'Close Now Playing')));
    expect(mode, lessThan(centerX(tester, 'Add to favorites')));
  });

  testWidgets('a gap, not a line, separates the left groups', (tester) async {
    await pump(tester);
    expect(find.byType(VerticalDivider), findsNothing);
    final gap =
        centerX(tester, 'Add to favorites') -
        centerX(tester, 'Close Now Playing');
    // Two buttons' width plus the gap.
    expect(gap, 48 + 16);
  });

  testWidgets('the right separator shows only with window buttons', (
    tester,
  ) async {
    await pump(tester, windowButtons: true);
    final line = find.byType(VerticalDivider);
    expect(line, findsOneWidget);
    expect(
      tester.getCenter(line).dx,
      greaterThan(tester.getRect(find.byType(VolumeButton)).right),
    );

    await pump(tester);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('shuffle and repeat change the player', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expect(container.read(playerServiceProvider).queue.shuffled, isTrue);

    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat the whole queue'));
    await tester.pumpAndSettle();
    expect(container.read(playerServiceProvider).queue.repeat, RepeatMode.all);
  });

  testWidgets('wraps its two groups in the drag exclusion', (tester) async {
    await pump(tester, exclude: true);

    expect(find.byType(_Excluded), findsNWidgets(2));
    // Everything that can be pressed is inside one of them.
    for (final tooltip in [
      'Close Now Playing',
      'Add to favorites',
      'Shuffle',
      'Sleep timer',
      'Mute',
    ]) {
      expect(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(_Excluded),
        ),
        findsOneWidget,
        reason: tooltip,
      );
    }
  });

  testWidgets('the volume popup opens below the button and sets floatingOpen', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 700));
    addTearDown(gesture.removePointer);
    expect(floating.value, isFalse);

    await gesture.moveTo(tester.getCenter(find.byType(VolumeButton)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(floating.value, isTrue);
    expect(
      tester.getRect(find.byType(Slider)).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(VolumeButton)).bottom),
    );

    await gesture.moveTo(const Offset(10, 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(floating.value, isFalse);
  });

  testWidgets('the sleep menu opens downward and sets floatingOpen', (
    tester,
  ) async {
    await pump(tester);
    final button = tester.getRect(find.byTooltip('Sleep timer'));

    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();

    expect(floating.value, isTrue);
    final menu = tester.getRect(find.text('15 minutes'));
    expect(menu.top, greaterThanOrEqualTo(button.bottom));

    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    expect(floating.value, isFalse);
  });

  testWidgets('the repeat menu sets floatingOpen while it is open', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(RepeatButton));
    await tester.pumpAndSettle();
    expect(floating.value, isTrue);

    await tester.tap(find.text('Repeat the current song'));
    await tester.pumpAndSettle();
    expect(floating.value, isFalse);
  });

  testWidgets('floatingOpen is cleared when the header leaves the tree', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();
    expect(floating.value, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(floating.value, isFalse);
  });

  testWidgets('the sleep label shows with room and drops without', (
    tester,
  ) async {
    await pump(tester);
    container.read(sleepTimerProvider.notifier).startMinutes(30);
    await tester.pump();
    expect(find.text('30:00'), findsOneWidget);

    // The right group is left with less than its buttons and the label.
    await pump(tester, width: 430);
    container.read(sleepTimerProvider.notifier).startMinutes(30);
    await tester.pump();
    expect(find.text('30:00'), findsNothing);
    expect(find.byTooltip('Sleep timer: 30:00 left'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the translation button', () {
    List<Override> scripted() => [
      fakeTranslationOverride(
        FakeTranslationController(TranslationOff(fakeTranslationInfo())),
      ),
    ];

    testWidgets('is absent unless the layout asks for it', (tester) async {
      await pump(tester);
      expect(find.byType(LyricsTranslationButton), findsNothing);
    });

    testWidgets('shows when the layout asks for it', (tester) async {
      await pump(tester, showTranslate: true, overrides: scripted());
      expect(find.byTooltip('Lyrics translation'), findsOneWidget);
    });

    testWidgets('sits right after the lyrics source button', (tester) async {
      await pump(tester, showTranslate: true, overrides: scripted());

      final source = tester.getRect(find.byType(LyricsSourceButton));
      final translate = tester.getRect(find.byType(LyricsTranslationButton));
      // The playlist button's 48 px slot ends where the source starts.
      expect(source.left, centerX(tester, 'Add to playlist') + 24);
      expect(translate.left - source.right, anyOf(0, nowPlayingPillGap));
      expect(translate.right, lessThan(centerX(tester, 'Shuffle')));
    });

    testWidgets('is disabled when told so', (tester) async {
      await pump(
        tester,
        showTranslate: true,
        translateEnabled: false,
        overrides: scripted(),
      );

      await tester.tap(
        find.byTooltip('Lyrics translation'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Show translation'), findsNothing);
      expect(floating.value, isFalse);
    });

    testWidgets('its menu sets floatingOpen while open', (tester) async {
      await pump(tester, showTranslate: true, overrides: scripted());

      await tester.tap(find.byTooltip('Lyrics translation'));
      await tester.pumpAndSettle();
      expect(floating.value, isTrue);

      await tester.tapAt(const Offset(600, 600));
      await tester.pumpAndSettle();
      expect(floating.value, isFalse);
    });

    testWidgets('floatingOpen is cleared when the header leaves', (
      tester,
    ) async {
      await pump(tester, showTranslate: true, overrides: scripted());
      await tester.tap(find.byTooltip('Lyrics translation'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());

      expect(floating.value, isFalse);
    });

    group('as a pill', () {
      List<Override> ready([String target = 'en']) => [
        fakeTranslationOverride(
          FakeTranslationController(
            TranslationReady(
              fakeTranslationInfo(defaultCode: target),
              LyricsTranslationService.google,
              'ja',
              const [],
              false,
            ),
          ),
        ),
      ];

      testWidgets('shows the credit at 1280 px and opens the menu', (
        tester,
      ) async {
        await pump(tester, showTranslate: true, overrides: ready());

        expect(find.text('Google · English'), findsOneWidget);
        await tester.tap(find.text('Google · English'));
        await tester.pumpAndSettle();
        expect(find.text('Show translation'), findsOneWidget);
        expect(floating.value, isTrue);
      });

      testWidgets('leaves a gap between the source pill and the translate '
          'icon', (tester) async {
        await pump(tester, showTranslate: true, overrides: scripted());

        expect(find.textContaining('Google ·'), findsNothing);
        expect(
          tester.getRect(find.byType(LyricsTranslationButton)).left -
              tester.getRect(find.byType(LyricsSourceButton)).right,
          nowPlayingPillGap,
        );
      });

      testWidgets('leaves a gap after the lyrics source pill', (tester) async {
        await pump(tester, showTranslate: true, overrides: ready());

        expect(find.text('Google · English'), findsOneWidget);
        expect(
          tester.getRect(find.byType(LyricsTranslationButton)).left -
              tester.getRect(find.byType(LyricsSourceButton)).right,
          nowPlayingPillGap,
        );
      });

      testWidgets('the pill moves no other header button', (tester) async {
        await pump(tester, showTranslate: true, overrides: scripted());
        final shuffle = tester.getRect(find.byType(ShuffleButton));
        // Unmounting schedules the disposal of providers the header watched;
        // let it run before the next one replaces it.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await pump(tester, showTranslate: true, overrides: ready());

        expect(tester.getRect(find.byType(ShuffleButton)), shuffle);
      });

      for (final locale in const [Locale('en'), Locale('vi')]) {
        testWidgets('stays an icon at 720 px beside the window buttons, '
            '${locale.languageCode}', (tester) async {
          await pump(
            tester,
            width: 720,
            windowButtons: true,
            showTranslate: true,
            locale: locale,
            overrides: ready(),
            modeButton: const SizedBox(width: 48, height: 48),
          );
          container.read(sleepTimerProvider.notifier).startMinutes(719);
          await tester.pump();

          expect(find.byType(IconButton), findsWidgets);
          expect(find.textContaining('Google ·'), findsNothing);
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.byType(LyricsTranslationButton)).right,
            lessThan(tester.getRect(find.byType(ShuffleButton)).left),
          );
        });
      }

      testWidgets('a long Vietnamese language fits without overflow', (
        tester,
      ) async {
        await pump(
          tester,
          width: 900,
          showTranslate: true,
          locale: const Locale('vi'),
          overrides: ready('zh-Hant'),
          modeButton: const SizedBox(width: 48, height: 48),
        );
        container.read(sleepTimerProvider.notifier).startMinutes(719);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final header = tester.getRect(find.byType(NowPlayingHeader));
        expect(
          tester.getRect(find.byType(VolumeButton)).right,
          lessThanOrEqualTo(header.right),
        );
        expect(
          tester.getRect(find.byType(LyricsTranslationButton)).right,
          lessThanOrEqualTo(tester.getRect(find.byType(ShuffleButton)).left),
        );
      });

      testWidgets('at the tightest edge the pill and sleep label both fit', (
        tester,
      ) async {
        // Header 768 px wide: after the gap between them, each of the two
        // pills gets a label room just above the 64 px minimum.
        await pump(
          tester,
          width: 768 + windowButtons,
          windowButtons: true,
          textScale: 1.5,
          showTranslate: true,
          locale: const Locale('vi'),
          overrides: ready('zh-Hant'),
          modeButton: const SizedBox(width: 48, height: 48),
        );
        container.read(sleepTimerProvider.notifier).startMinutes(30);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('30:00'), findsOneWidget);
        final label = find.textContaining('Google ·');
        expect(label, findsOneWidget);
        final text = tester.widget<Text>(label);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.getSize(label).width, lessThanOrEqualTo(64 + 16));
        expect(
          tester.getRect(find.byType(VolumeButton)).right,
          lessThanOrEqualTo(
            tester.getRect(find.byType(NowPlayingHeader)).right,
          ),
        );
      });

      testWidgets('an open menu and floatingOpen survive loading to ready', (
        tester,
      ) async {
        final info = fakeTranslationInfo();
        const google = LyricsTranslationService.google;
        final controller = FakeTranslationController(TranslationOff(info));
        await pump(
          tester,
          showTranslate: true,
          overrides: [fakeTranslationOverride(controller)],
        );
        await tester.tap(find.byType(LyricsTranslationButton));
        await tester.pumpAndSettle();
        expect(floating.value, isTrue);

        // A running ring never settles: step the frames by hand.
        controller.emit(TranslationLoading(info, google));
        await tester.pump(const Duration(milliseconds: 300));
        controller.emit(TranslationReady(info, google, 'ja', const [], false));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Google · English'), findsOneWidget);
        expect(find.text('Show translation'), findsOneWidget);
        expect(floating.value, isTrue);
      });

      testWidgets('keeps the sleep timer label while the pill shows', (
        tester,
      ) async {
        await pump(
          tester,
          width: 1000,
          showTranslate: true,
          overrides: ready(),
        );
        container.read(sleepTimerProvider.notifier).startMinutes(30);
        await tester.pump();

        expect(find.text('Google · English'), findsOneWidget);
        expect(find.text('30:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    test('the label room budget', () {
      // Left: 30 inset, 5 buttons (close, favorite, playlist, translate,
      // source) and a 16 gap. Right: 4 buttons and the 56 sleep label. A pill
      // replaces its 48 px button and spends 60 px on padding and icon.
      ({double source, double translate}) rooms(
        double width, {
        bool mode = false,
        bool window = false,
        bool pill = false,
      }) => nowPlayingPillLabelRooms(
        width: width,
        hasModeButton: mode,
        hasWindowButtons: window,
        translatePill: pill,
      );

      // The translation is an icon: the source label gets all of the room.
      expect(rooms(598).source, 52 - nowPlayingPillGap);
      expect(rooms(598).translate, 0);
      expect(rooms(552, mode: true, window: true).source, lessThan(0));
      expect(rooms(720, mode: true).source, greaterThan(64));
      expect(
        rooms(720, mode: true).source -
            rooms(720, mode: true, window: true).source,
        25,
      );

      // Both are pills: the room is split in two, from what is left after
      // both pills replaced a button each and the gap between them.
      final both = rooms(1000, pill: true);
      expect(both.source, both.translate);
      expect(both.source, (1000 - 286 - 248 - 24 - nowPlayingPillGap) / 2);
    });

    for (final locale in const [Locale('en'), Locale('vi')]) {
      testWidgets('fits 720 px with every button, ${locale.languageCode}', (
        tester,
      ) async {
        await pump(
          tester,
          width: 720,
          windowButtons: true,
          showTranslate: true,
          locale: locale,
          overrides: scripted(),
          modeButton: const SizedBox(width: 48, height: 48),
        );
        container.read(sleepTimerProvider.notifier).startMinutes(719);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final header = tester.getRect(find.byType(NowPlayingHeader));
        final translate = tester.getRect(find.byType(LyricsTranslationButton));
        expect(
          translate.right,
          lessThan(tester.getRect(find.byType(ShuffleButton)).left),
        );
        expect(
          tester.getRect(find.byType(VolumeButton)).right,
          lessThanOrEqualTo(header.right),
        );
      });
    }
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('fits 720 px beside the window buttons at text scale $scale', (
      tester,
    ) async {
      await pump(tester, width: 720, windowButtons: true, textScale: scale);
      container.read(sleepTimerProvider.notifier).startMinutes(719);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(NowPlayingHeader));
      expect(header.right, 720 - windowButtons);
      expect(
        tester.getRect(find.byType(VolumeButton)).right,
        lessThanOrEqualTo(header.right),
      );
      expect(
        tester.getRect(find.byTooltip('Add to playlist')).right,
        lessThan(tester.getRect(find.byTooltip('Shuffle')).left),
      );
    });
  }

  group('the lyrics source button', () {
    const uri = '/music/a.mp3';

    /// Online lyrics with a long service name, so the label needs room.
    List<Override> longLabel() => [
      playingLyricsResolutionProvider.overrideWith(
        () => FakePlayingLyricsResolution(
          fakeResolution(
            LyricsFound(
              uri,
              fakeSyncedLyrics(),
              origin: const OnlineLyricsOrigin(
                providerId: 'a-long-service-name',
                remoteId: '1',
                pinned: true,
              ),
            ),
            effective: LyricsChoice.online,
          ),
        ),
      ),
    ];

    List<Override> translated() => [
      fakeTranslationOverride(
        FakeTranslationController(
          TranslationReady(
            fakeTranslationInfo(),
            LyricsTranslationService.google,
            'ja',
            const [],
            false,
          ),
        ),
      ),
    ];

    testWidgets('comes before the translate button and shows the source', (
      tester,
    ) async {
      await pump(
        tester,
        showTranslate: true,
        overrides: [...longLabel(), ...translated()],
      );
      final translate = tester.getRect(find.byType(LyricsTranslationButton));
      final source = tester.getRect(find.byType(LyricsSourceButton));
      expect(translate.left, greaterThanOrEqualTo(source.right));
      expect(find.text('a-long-service-name · Synced'), findsOneWidget);
    });

    testWidgets('is only its icon when lyrics are off', (tester) async {
      await pump(
        tester,
        showTranslate: true,
        overrides: [
          playingLyricsResolutionProvider.overrideWith(
            () => FakePlayingLyricsResolution(
              fakeResolution(
                const LyricsNone(uri, LyricsNoneReason.off),
                chosen: LyricsChoice.off,
                effective: LyricsChoice.off,
              ),
            ),
          ),
        ],
      );

      final source = tester.getRect(find.byType(LyricsSourceButton));
      expect(find.text('Lyrics off'), findsNothing);
      expect(source.width, lessThanOrEqualTo(48));
      // No pill, so no gap: the translate icon sits beside it like the
      // other round buttons.
      expect(
        tester.getRect(find.byType(LyricsTranslationButton)).left,
        source.right,
      );
    });

    testWidgets('is absent when the layout hides the lyrics buttons', (
      tester,
    ) async {
      await pump(tester, overrides: longLabel());
      expect(find.byType(LyricsSourceButton), findsNothing);
    });

    testWidgets('its menu sets floatingOpen while it is open', (tester) async {
      await pump(tester, showTranslate: true, overrides: longLabel());
      await tester.tap(find.byType(LyricsSourceButton));
      await tester.pumpAndSettle();
      expect(find.text('Automatic'), findsOneWidget);
      expect(floating.value, isTrue);

      await tester.tapAt(const Offset(600, 600));
      await tester.pumpAndSettle();
      expect(floating.value, isFalse);
    });

    testWidgets('floatingOpen is cleared when the header leaves', (
      tester,
    ) async {
      await pump(tester, showTranslate: true, overrides: longLabel());
      await tester.tap(find.byType(LyricsSourceButton));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());

      expect(floating.value, isFalse);
    });

    for (final width in [600.0, 720.0, 800.0, 1000.0, 1600.0]) {
      for (final window in [false, true]) {
        if (window && width < 720) continue;
        for (final translatePill in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            testWidgets('fits $width px, window buttons $window, translation '
                '${translatePill ? 'pill' : 'icon'}, text scale $scale', (
              tester,
            ) async {
              await pump(
                tester,
                width: width,
                windowButtons: window,
                textScale: scale,
                showTranslate: true,
                modeButton: width >= 720
                    ? const SizedBox(width: 48, height: 48)
                    : null,
                overrides: [...longLabel(), if (translatePill) ...translated()],
              );
              container.read(sleepTimerProvider.notifier).startMinutes(719);
              await tester.pump();

              expect(tester.takeException(), isNull);
              final header = tester.getRect(find.byType(NowPlayingHeader));
              final translate = tester.getRect(
                find.byType(LyricsTranslationButton),
              );
              final source = tester.getRect(find.byType(LyricsSourceButton));
              expect(translate.left, greaterThanOrEqualTo(source.right));
              expect(
                source.right,
                lessThanOrEqualTo(
                  tester.getRect(find.byType(ShuffleButton)).left,
                ),
              );
              expect(
                tester.getRect(find.byType(VolumeButton)).right,
                lessThanOrEqualTo(header.right),
              );
            });
          }
        }
      }
    }
  });
}
