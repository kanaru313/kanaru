import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_cover.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

final songs = [
  Track.fromPath('/music/First Song.flac'),
  Track.fromPath('/music/Second Song.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  bool isOpen() => container.read(nowPlayingOpenProvider);
  final screen = find.byType(NowPlayingScreen);

  /// Animations off by default: the slide would need explicit pumps.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    bool animations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !animations);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSongs(WidgetTester tester) async {
    await player().openTracks(songs);
    backend.calls.clear();
    await tester.pumpAndSettle();
  }

  Future<void> openNowPlaying(WidgetTester tester) async {
    await tester.tap(find.byType(NowPlayingOpenCover));
    await tester.pumpAndSettle();
  }

  group('open state', () {
    test('opens and closes', () async {
      backend = FakeAudioBackend();
      container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);
      container.listen(playerServiceProvider, (_, _) {});
      final open = container.read(nowPlayingOpenProvider.notifier);

      await player().openTracks(songs);
      open.open();
      expect(isOpen(), isTrue);
      open.close();
      expect(isOpen(), isFalse);
    });

    test('does not open with an empty queue', () {
      backend = FakeAudioBackend();
      container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);
      container.listen(playerServiceProvider, (_, _) {});

      container.read(nowPlayingOpenProvider.notifier).open();
      expect(isOpen(), isFalse);
    });

    test('closes when the queue is emptied', () async {
      backend = FakeAudioBackend();
      container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);
      container.listen(playerServiceProvider, (_, _) {});
      container.listen(nowPlayingOpenProvider, (_, _) {});

      await player().openTracks([songs.first]);
      container.read(nowPlayingOpenProvider.notifier).open();
      await player().removeTrack(0);

      expect(isOpen(), isFalse);
    });
  });

  group('opening', () {
    testWidgets('hovering the cover shows the expand icon', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      AnimatedOpacity iconOpacity() => tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.open_in_full),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(iconOpacity().opacity, 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(NowPlayingOpenCover)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(iconOpacity().opacity, 1);
      await mouse.moveTo(const Offset(600, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(iconOpacity().opacity, 0);
    });

    testWidgets('clicking the cover opens Now Playing', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      expect(screen, findsNothing);

      await openNowPlaying(tester);

      expect(screen, findsOneWidget);
      expect(isOpen(), isTrue);
    });

    testWidgets('does not open while nothing is queued', (tester) async {
      await pumpApp(tester);

      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
    });

    testWidgets('slides up over 500 ms', (tester) async {
      await pumpApp(tester, animations: true);
      await player().openTracks(songs);
      await tester.pump(const Duration(milliseconds: 100));

      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(screen).dy, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(screen).dy, 0);
    });
  });

  group('closing', () {
    testWidgets('with the close button', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);

      await tester.tap(find.byTooltip('Close Now Playing'));
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
      expect(isOpen(), isFalse);
    });

    testWidgets('with Esc, every time it opens', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);

      for (var i = 0; i < 2; i++) {
        await openNowPlaying(tester);
        expect(screen, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(screen, findsNothing);
      }
    });

    testWidgets('with the mouse back button, not touching history', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSongs(tester);
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      await openNowPlaying(tester);

      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await mouse.down(const Offset(600, 300));
      await mouse.up();
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
      // Back only closed the overlay: the page was not left.
      expect(container.read(navigationHistoryProvider).canGoForward, isFalse);
    });

    testWidgets('when the queue is emptied', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);

      await player().clearQueue();
      await player().removeTrack(0);
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
    });

    testWidgets('leaves nothing of Now Playing in the tree', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Close Now Playing'), findsNothing);
      expect(find.byType(NowPlayingScreen), findsNothing);
    });
  });

  group('while open', () {
    testWidgets('Tab never reaches the shell', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);

      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        expect(focused, isNotNull);
        expect(
          focused!.findAncestorWidgetOfExactType<NowPlayingScreen>(),
          isNotNull,
        );
      }
    });

    testWidgets('Space still plays and pauses', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(backend.calls, ['pause']);
    });

    /// Taps [target] in the shell, which must still be drawn, and expects no
    /// navigation. [coveredByScreen] tells whether the sliding screen is
    /// expected to sit over the target (its own surface blocks the tap) or
    /// clear of it (only the shell ignoring pointers blocks it).
    Future<void> tapShell(
      WidgetTester tester,
      Finder target, {
      required bool coveredByScreen,
    }) async {
      expect(target, findsOneWidget, reason: 'the shell is still drawn');
      final at = tester.getCenter(target);
      final screenTop = tester.getRect(screen).top;
      expect(screenTop < at.dy, coveredByScreen);
      await tester.tapAt(at);
      await tester.pump();
      expect(container.read(navigationHistoryProvider).canGoBack, isFalse);
    }

    Future<void> slideIn(WidgetTester tester, Duration elapsed) async {
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pump();
      await tester.pump(elapsed);
    }

    Future<void> slideOut(WidgetTester tester, Duration elapsed) async {
      await slideIn(tester, const Duration(seconds: 1));
      container.read(nowPlayingOpenProvider.notifier).close();
      await tester.pump();
      await tester.pump(elapsed);
    }

    // The settings button and the sidebar item stand for the shell parts the
    // screen has not reached yet and those it already covers.
    final settings = find.byTooltip('Settings');
    final artists = find.text('Artists');

    testWidgets('the shell below ignores pointers while sliding in', (
      tester,
    ) async {
      await pumpApp(tester, animations: true);
      await openSongs(tester);

      await slideIn(tester, const Duration(milliseconds: 100));
      await tapShell(tester, settings, coveredByScreen: false);

      await tester.pump(const Duration(milliseconds: 300));
      await tapShell(tester, artists, coveredByScreen: true);
    });

    testWidgets('the shell below ignores pointers while sliding out', (
      tester,
    ) async {
      await pumpApp(tester, animations: true);
      await openSongs(tester);

      await slideOut(tester, const Duration(milliseconds: 100));
      // Only the part under the screen: the shell is open to pointers again
      // as soon as closing starts, so the part clear of it is not blocked.
      await tapShell(tester, artists, coveredByScreen: true);
    });

    testWidgets('a playback error shows over Now Playing', (tester) async {
      await pumpApp(tester);
      await openSongs(tester);
      await openNowPlaying(tester);

      backend.fail(songs.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: screen,
          matching: find.text("Couldn't play First Song"),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the page below keeps its state', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      // Short enough for the settings list to scroll.
      tester.view.physicalSize = const Size(1280, 300);
      await tester.pumpAndSettle();
      await openSongs(tester);
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -80));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(list).position.pixels;
      expect(offset, greaterThan(0));

      await openNowPlaying(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        offset,
      );
    });
  });
}
