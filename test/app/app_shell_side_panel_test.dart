import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/top_bar.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/synced_lyrics_view.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_sheet_host.dart';
import 'package:kanaru/features/player/sleep_timer/sleep_timer_button.dart';
import 'package:kanaru/features/player/side_panel/player_side_panel.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../core/lyrics/fake_lyrics_readers.dart';
import '../core/player/fake_audio_backend.dart';

final _tracks = [
  for (var i = 0; i < 4; i++)
    Track(uri: '/music/t$i.mp3', title: 'Song $i', artist: 'Artist $i'),
];

/// The docked side panel in the app shell.
void main() {
  late ProviderContainer container;
  late FakeLrcSidecarReader sidecar;

  DisplayPrefs display() => container.read(settingsProvider).display;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    DisplayPrefs prefs = const DisplayPrefs(),
    bool queueTracks = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    sidecar = FakeLrcSidecarReader()
      ..byPath['/music/t1.mp3'] = '[00:00.00]First words\n[00:05.00]More words';
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        initialSettingsProvider.overrideWithValue(AppSettings(display: prefs)),
        lrcSidecarReaderProvider.overrideWithValue(sidecar),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    if (queueTracks) {
      await container.read(playerServiceProvider.notifier).openTracks(_tracks);
      await tester.pumpAndSettle();
    }
  }

  /// Moves the keyboard focus to the button that [tooltip] names.
  Future<FocusNode> focusButton(WidgetTester tester, Finder button) async {
    final node = Focus.of(
      tester.element(
        find.descendant(of: button, matching: find.byType(Icon)).first,
      ),
    )..requestFocus();
    await tester.pump();
    return node;
  }

  final bar = find.byType(PlayerBar);
  final panel = find.byType(PlayerSidePanel);
  final queueButton = find.descendant(
    of: bar,
    matching: find.byTooltip('Show now playing list'),
  );
  final closeQueueButton = find.descendant(
    of: bar,
    matching: find.byTooltip('Close now playing list'),
  );
  final lyricsButton = find.descendant(
    of: bar,
    matching: find.byTooltip('Show lyrics'),
  );

  group('wide window', () {
    testWidgets('the queue button docks the panel beside the page', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(panel, findsNothing);

      await tester.tap(queueButton);
      await tester.pumpAndSettle();

      expect(panel, findsOneWidget);
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(QueueSheetHost.maybeOf(tester.element(panel))!.isOpen, isFalse);
      expect(display().sidePanelOpen, isTrue);
      // 360 px at the right edge, under the top bar, above the player bar.
      final rect = tester.getRect(panel);
      expect(rect.right, 1400);
      expect(rect.width, 360);
      expect(rect.top, tester.getRect(find.byType(TopBar)).bottom);
      expect(rect.bottom, tester.getTopLeft(bar).dy);
      // No scrim: the top bar stays reachable.
      expect(
        find
            .descendant(
              of: find.byType(TopBar),
              matching: find.byType(TextField),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('Close now playing list'), findsOneWidget);
    });

    testWidgets('the queue button closes the panel again', (tester) async {
      await pumpApp(tester);
      await tester.tap(queueButton);
      await tester.pumpAndSettle();

      await tester.tap(closeQueueButton);
      await tester.pumpAndSettle();

      expect(panel, findsNothing);
      expect(display().sidePanelOpen, isFalse);
    });

    testWidgets('a remembered open panel shows at the first frame', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      expect(panel, findsOneWidget);
    });

    testWidgets('the lyrics button opens the lyrics tab; the queue button '
        'switches back', (tester) async {
      await pumpApp(tester);

      await tester.tap(lyricsButton);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(display().sidePanelTab, SidePanelTab.lyrics);
      expect(find.byType(QueuePanel), findsNothing);
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.controller!.index, 1);

      // The panel is on Lyrics: the queue button is not selected and shows it.
      await tester.tap(queueButton);
      await tester.pumpAndSettle();
      expect(display().sidePanelOpen, isTrue);
      expect(display().sidePanelTab, SidePanelTab.queue);
      expect(tabs.controller!.index, 0);
      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('a tab press writes the tab once', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      var writes = 0;
      container.listen(settingsProvider, (_, _) => writes++);

      await tester.tap(
        find.descendant(of: panel, matching: find.text('Lyrics')),
      );
      await tester.pumpAndSettle();

      expect(display().sidePanelTab, SidePanelTab.lyrics);
      expect(writes, 1);
    });

    testWidgets('the close button closes the panel', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));

      await tester.tap(find.byTooltip('Close side panel'));
      await tester.pumpAndSettle();

      expect(panel, findsNothing);
      expect(display().sidePanelOpen, isFalse);
    });

    testWidgets('no queued track, no panel and no bar', (tester) async {
      await pumpApp(
        tester,
        prefs: const DisplayPrefs(sidePanelOpen: true),
        queueTracks: false,
      );
      expect(bar, findsNothing);
      expect(panel, findsNothing);
    });

    testWidgets('1360 px leaves the page 720 px or more', (tester) async {
      await pumpApp(
        tester,
        size: const Size(1360, 768),
        prefs: const DisplayPrefs(sidePanelOpen: true),
      );
      final page = tester.getSize(find.byType(TopBar)).width;
      // The top bar spans the page area and the panel: take the panel off.
      expect(page - 361, greaterThanOrEqualTo(720));
      expect(tester.getSize(panel).width, 360);
    });

    testWidgets('toggling the panel does not rebuild the top bar', (
      tester,
    ) async {
      await pumpApp(tester);
      var rebuilds = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        if (element.widget is TopBar) rebuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);

      await tester.tap(queueButton);
      await tester.pumpAndSettle();
      await tester.tap(closeQueueButton);
      await tester.pumpAndSettle();

      expect(rebuilds, 0);
    });
  });

  group('narrow window', () {
    testWidgets('no lyrics button; the queue button opens the sheet', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1300, 900));
      expect(lyricsButton, findsNothing);

      await tester.tap(queueButton);
      await tester.pumpAndSettle();

      expect(panel, findsNothing);
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(display().sidePanelOpen, isFalse);
    });

    testWidgets('narrowing hides the panel but keeps the setting; the button '
        'opens the sheet; widening docks it again', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      expect(panel, findsOneWidget);

      tester.view.physicalSize = const Size(1300, 900);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(display().sidePanelOpen, isTrue);
      // The hidden panel does not mark the button selected.
      expect(find.byTooltip('Close now playing list'), findsNothing);

      await tester.tap(queueButton);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(display().sidePanelOpen, isTrue);
      await tester.tap(closeQueueButton);
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsNothing);

      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
    });
  });

  group('Now Playing open', () {
    testWidgets('the footer queue button keeps the sheet', (tester) async {
      await pumpApp(tester);
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show now playing list').last);
      await tester.pumpAndSettle();

      expect(display().sidePanelOpen, isFalse);
      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('the shell lyrics tab shows no lyrics view behind it', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: const DisplayPrefs(
          sidePanelOpen: true,
          sidePanelTab: SidePanelTab.lyrics,
        ),
      );
      await container
          .read(playerServiceProvider.notifier)
          .openTracks(_tracks, start: 1);
      await tester.pumpAndSettle();
      expect(find.byType(SyncedLyricsView), findsOneWidget);

      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PlayerSidePanel, skipOffstage: false),
          matching: find.byType(SyncedLyricsView, skipOffstage: false),
        ),
        findsNothing,
      );
    });
  });

  group('Ctrl+F', () {
    late bool pageOpened;
    late InPageFilterHandle pageHandle;

    /// A page filter at the lowest layer, standing for a library page.
    void registerPageFilter(WidgetTester tester) {
      pageOpened = false;
      pageHandle = InPageFilterHandle(
        context: tester.element(find.byType(TopBar)),
        open: () => pageOpened = true,
        hasFocus: () => false,
      );
      InPageFilterRegistry.instance.register(pageHandle);
      addTearDown(() => InPageFilterRegistry.instance.unregister(pageHandle));
    }

    Future<void> ctrlF(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('reaches the page while the panel was not used', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);

      await ctrlF(tester);

      expect(pageOpened, isTrue);
      expect(find.byType(InPageSearchBox), findsNothing);
    });

    testWidgets('reaches the queue after a mouse press in the panel, and '
        'the page after a press on the page', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);

      await tester.tapAt(tester.getCenter(find.text('Song 2')));
      await tester.pump();
      await ctrlF(tester);
      expect(pageOpened, isFalse);
      expect(find.byType(InPageSearchBox), findsOneWidget);

      // Close the box, press on the page, ask again.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 450));
      await tester.pump();
      await ctrlF(tester);
      expect(pageOpened, isTrue);
    });

    testWidgets('goes back to the page once the focus moves out of the panel '
        'by keyboard', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);

      await tester.tapAt(tester.getCenter(find.text('Song 2')));
      await tester.pump();
      await focusButton(
        tester,
        find.descendant(of: bar, matching: find.byTooltip('Sleep timer')),
      );
      await ctrlF(tester);

      expect(pageOpened, isTrue);
      expect(find.byType(InPageSearchBox), findsNothing);
    });

    testWidgets('a press on the queue sheet drawn over the panel does not '
        'count as a press in the panel', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);
      QueueSheetHost.of(tester.element(panel)).open();
      await tester.pumpAndSettle();

      // Inside the panel's x-range, on the sheet.
      await tester.tapAt(const Offset(1300, 880 - 80));
      await tester.pump();
      QueueSheetHost.of(tester.element(bar)).close();
      await tester.pumpAndSettle();
      await ctrlF(tester);

      expect(pageOpened, isTrue);
    });

    testWidgets('a press in Now Playing over the panel does not count', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(1300, 400));
      await tester.pump();
      container.read(nowPlayingOpenProvider.notifier).close();
      await tester.pumpAndSettle();
      await ctrlF(tester);

      expect(pageOpened, isTrue);
    });

    testWidgets('Esc in the docked filter box closes only the box', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);
      await tester.tapAt(tester.getCenter(find.text('Song 2')));
      await tester.pump();
      await ctrlF(tester);
      expect(find.byType(InPageSearchBox), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(InPageSearchBox), findsNothing);
      expect(panel, findsOneWidget);
      expect(display().sidePanelOpen, isTrue);
    });

    testWidgets('reaches the queue when the keyboard focus is in the panel', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      registerPageFilter(tester);

      await focusButton(tester, find.byTooltip('Close side panel'));
      await ctrlF(tester);

      expect(pageOpened, isFalse);
      expect(find.byType(InPageSearchBox), findsOneWidget);
    });
  });

  group('focus', () {
    testWidgets('closing from the keyboard returns the focus to where it '
        'came from', (tester) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      final outside = await focusButton(
        tester,
        find.descendant(of: bar, matching: find.byTooltip('Sleep timer')),
      );
      await focusButton(tester, find.byTooltip('Close side panel'));
      expect(FocusManager.instance.primaryFocus, isNot(outside));

      await tester.tap(find.byTooltip('Close side panel'));
      await tester.pumpAndSettle();

      expect(panel, findsNothing);
      expect(FocusManager.instance.primaryFocus, outside);
    });

    testWidgets('closing with the mouse leaves the focus alone', (
      tester,
    ) async {
      await pumpApp(tester, prefs: const DisplayPrefs(sidePanelOpen: true));
      final focused = FocusManager.instance.primaryFocus;

      await tester.tap(find.byTooltip('Close side panel'));
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus, focused);
    });
  });

  for (final width in [1360.0, 1380.0, 1400.0, 1460.0]) {
    testWidgets('the sleep label is shown whole or not at all at $width px', (
      tester,
    ) async {
      await pumpApp(tester, size: Size(width, 800));
      final sleep = container.read(sleepTimerProvider.notifier);
      sleep.startMinutes(45);
      await tester.pump(const Duration(seconds: 1));

      final label = find.descendant(
        of: find.byType(SleepTimerButton),
        matching: find.textContaining(RegExp(r'^\d+:\d\d$')),
      );
      for (final element in label.evaluate()) {
        final paragraph = element.findRenderObject()! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      sleep.cancel();
      await tester.pumpAndSettle();
    });
  }
}
