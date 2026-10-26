import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/lyrics_line.dart';
import 'package:kanaru/features/player/lyrics/synced_lyrics_view.dart';
import 'package:kanaru/features/player/now_playing/now_playing_auto_hide.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_only_body.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';

/// Forty lines, one every second from 1 s: "line 0" … "line 39".
final _lyrics = Lyrics(
  lines: [
    for (var i = 0; i < 40; i++) LyricLine(Duration(seconds: i + 1), 'line $i'),
  ],
  synced: true,
  source: LyricsSource.sidecar,
);

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool lyricsOnly = false,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/m/a.flac', title: 'A'),
    ]);
    backend.emitDuration.add(const Duration(minutes: 1));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: lyricsOnly
                ? NowPlayingLyricsOnlyBody(
                    lyrics: SyncedLyricsView(lyrics: _lyrics),
                    chrome: AutoHideController(),
                    onShowSplit: () {},
                  )
                : SyncedLyricsView(lyrics: _lyrics),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextStyle styleOf(WidgetTester tester, String text) => tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style;

  bool isCurrent(WidgetTester tester, String text) =>
      styleOf(tester, text).fontWeight == FontWeight.w700;

  double centerY(WidgetTester tester, String text) =>
      tester.getCenter(find.text(text)).dy;

  Future<void> playAt(WidgetTester tester, Duration position) async {
    backend.emitPosition.add(position);
    await tester.pumpAndSettle();
  }

  testWidgets('before the first line nothing is current', (tester) async {
    await pump(tester);
    expect(isCurrent(tester, 'line 0'), isFalse);
    // The first line waits at the anchor, 40% down the 400 px view.
    expect(centerY(tester, 'line 0'), closeTo(160, 30));
  });

  testWidgets('the current line follows the position and is scrolled to', (
    tester,
  ) async {
    await pump(tester);
    await playAt(tester, const Duration(milliseconds: 1500));
    expect(isCurrent(tester, 'line 0'), isTrue);

    await playAt(tester, const Duration(seconds: 20, milliseconds: 100));
    expect(isCurrent(tester, 'line 0'), isFalse);
    expect(isCurrent(tester, 'line 19'), isTrue);
    expect(centerY(tester, 'line 19'), closeTo(160, 30));
  });

  testWidgets('a position tick inside the same line rebuilds no line', (
    tester,
  ) async {
    await pump(tester);
    await playAt(tester, const Duration(seconds: 5));
    final before = tester.widget<LyricsLine>(find.byType(LyricsLine).first);
    final lineElement = tester.element(find.text('line 4'));
    await playAt(tester, const Duration(seconds: 5, milliseconds: 500));
    // Same widget instances and elements: nothing above the lines rebuilt.
    expect(
      tester.widget<LyricsLine>(find.byType(LyricsLine).first),
      same(before),
    );
    expect(tester.element(find.text('line 4')), same(lineElement));
  });

  testWidgets('a line change glides for 200 ms, then nothing draws', (
    tester,
  ) async {
    await pump(tester);
    await playAt(tester, const Duration(milliseconds: 4500));

    backend.emitPosition.add(const Duration(milliseconds: 5500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = centerY(tester, 'line 4');
    await tester.pump(const Duration(milliseconds: 100));
    final arrived = centerY(tester, 'line 4');
    await tester.pump(const Duration(seconds: 1));

    expect(arrived, centerY(tester, 'line 4'), reason: 'done after 200 ms');
    expect(midway, isNot(arrived), reason: 'not instant');
    expect(isCurrent(tester, 'line 4'), isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a line change draws about 13 frames, no scrollbar flash', (
    tester,
  ) async {
    // Desktop platforms put a scrollbar on every scrollable: it must not
    // fade in and out on the view's own scrolling.
    await pump(tester, platform: TargetPlatform.linux);
    await playAt(tester, const Duration(milliseconds: 4500));

    backend.emitPosition.add(const Duration(milliseconds: 5500));
    var frames = 0;
    for (var t = 0; t < 2000; t += 16) {
      if (tester.binding.hasScheduledFrame) frames++;
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(frames, inInclusiveRange(10, 14));
  });

  testWidgets('scrolling by hand still shows the scrollbar', (tester) async {
    await pump(tester, platform: TargetPlatform.linux);
    await playAt(tester, const Duration(seconds: 3));
    double thumbOpacity() {
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
        ),
      );
      return (paint.foregroundPainter! as ScrollbarPainter)
          .fadeoutOpacityAnimation
          .value;
    }

    // Long enough for a thumb shown by the auto-scroll to have faded again.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(thumbOpacity(), 0);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    // The fade-in starts on the first frame, then runs for 300 ms.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(thumbOpacity(), 1);
    await tester.pumpAndSettle();
  });

  ScrollbarPainter scrollbarPainter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) =>
                      w is CustomPaint &&
                      w.foregroundPainter is ScrollbarPainter,
                ),
              )
              .foregroundPainter!
          as ScrollbarPainter;

  /// Scrolls by hand once (so the painter knows a position), then lets
  /// auto-scroll take over for three lines far down the list. Returns the
  /// scroll position. The manual-scroll pause is shorter than its timer.
  Future<ScrollPosition> manualThenAutoScroll(WidgetTester tester) async {
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump(lyricsManualScrollPause);
    await tester.pumpAndSettle();
    for (final s in [10, 20, 30]) {
      await playAt(tester, Duration(seconds: s));
    }
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.pixels, greaterThan(500));
    return position;
  }

  Future<void> expectHoveredThumbAtOffset(
    WidgetTester tester,
    ScrollPosition position,
  ) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(300, 200));
    await mouse.moveTo(const Offset(598, 200));
    await tester.pumpAndSettle();

    final viewport = position.viewportDimension;
    final max = position.maxScrollExtent;
    final length = viewport * viewport / (viewport + max);
    final centerY = position.pixels / max * (viewport - length) + length / 2;
    // The tolerance is intentionally large: the hit test accepts any point on
    // the thumb (about `length` px tall), while the stale thumb of a missed
    // resync sits hundreds of px away, so a small tolerance adds nothing.
    // The scaffold body starts at y = 0 in this 600 x 400 view.
    expect(
      scrollbarPainter(tester).hitTestOnlyThumbInteractive(
        Offset(594, centerY),
        PointerDeviceKind.mouse,
      ),
      isTrue,
      reason: 'thumb must be drawn at the current offset ${position.pixels}',
    );
  }

  testWidgets('after auto-scroll the hovered thumb sits at the offset', (
    tester,
  ) async {
    await pump(tester, platform: TargetPlatform.linux);
    final position = await manualThenAutoScroll(tester);
    await expectHoveredThumbAtOffset(tester, position);
  });

  testWidgets('with reduced motion the hovered thumb sits at the offset', (
    tester,
  ) async {
    await pump(tester, platform: TargetPlatform.linux, reduceMotion: true);
    final position = await manualThenAutoScroll(tester);
    await expectHoveredThumbAtOffset(tester, position);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('the scrollbar resync after auto-scroll does not fade it in '
        '(reduceMotion: $reduceMotion)', (tester) async {
      await pump(
        tester,
        platform: TargetPlatform.linux,
        reduceMotion: reduceMotion,
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -80),
      );
      await tester.pump(lyricsManualScrollPause);
      await tester.pumpAndSettle();
      expect(scrollbarPainter(tester).fadeoutOpacityAnimation.value, 0);

      backend.emitPosition.add(const Duration(seconds: 30));
      // Frame by frame through the glide and the resync after it: the
      // thumb never starts to fade in.
      for (var t = 0; t < 600; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          scrollbarPainter(tester).fadeoutOpacityAnimation.value,
          0,
          reason: 'thumb visible $t ms after the line change',
        );
      }
    });
  }

  testWidgets('a line change draws only the lines that change', (tester) async {
    await pump(tester);
    await playAt(tester, const Duration(milliseconds: 4500));
    final bystander = tester.renderObject(find.text('line 8'));
    final changing = tester.renderObject(find.text('line 4'));

    final painted = <RenderObject, int>{};
    debugOnProfilePaint = (object) =>
        painted.update(object, (n) => n + 1, ifAbsent: () => 1);
    try {
      backend.emitPosition.add(const Duration(milliseconds: 5500));
      await tester.pumpAndSettle();
    } finally {
      debugOnProfilePaint = null;
    }

    // The view scrolled past it, but its picture was reused.
    expect(painted[bystander], isNull);
    expect(painted[changing], isNotNull);
  });

  testWidgets('pressing a line seeks to it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('line 2'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('seek(0:00:03.000000)'));
    expect(isCurrent(tester, 'line 2'), isTrue);
  });

  testWidgets('scrolling by hand pauses auto-scroll for a while', (
    tester,
  ) async {
    await pump(tester);
    await playAt(tester, const Duration(seconds: 3));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    final scrolledTo = centerY(tester, 'line 2');

    // The line changes, but the view stays where the user put it.
    await playAt(tester, const Duration(seconds: 4));
    expect(isCurrent(tester, 'line 3'), isTrue);
    expect(centerY(tester, 'line 2'), scrolledTo);

    // After the pause it comes back to the current line.
    await tester.pump(lyricsManualScrollPause);
    await tester.pumpAndSettle();
    expect(centerY(tester, 'line 3'), closeTo(160, 30));
  });

  testWidgets('lines closer than the scroll animation do not pause it', (
    tester,
  ) async {
    await pump(tester);
    backend.emitPosition.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    backend.emitPosition.add(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Still following: a later line is scrolled to at once.
    await playAt(tester, const Duration(seconds: 20));
    expect(centerY(tester, 'line 19'), closeTo(160, 30));
  });

  testWidgets('with reduced motion the view jumps instead of animating', (
    tester,
  ) async {
    await pump(tester, reduceMotion: true);
    backend.emitPosition.add(const Duration(seconds: 30));
    await tester.pump();
    // Already in place on the very next frame.
    expect(centerY(tester, 'line 29'), closeTo(160, 30));
  });

  group('in the lyrics-only body', () {
    double fontSize(WidgetTester tester, String text) =>
        styleOf(tester, text).fontSize!;

    testWidgets('every line has the headlineMedium size', (tester) async {
      await pump(tester, lyricsOnly: true);
      final medium = Theme.of(tester.element(find.byType(SyncedLyricsView)))
          .textTheme
          .headlineMedium!
          .fontSize;
      await playAt(tester, const Duration(milliseconds: 5500));

      expect(isCurrent(tester, 'line 4'), isTrue);
      expect(fontSize(tester, 'line 4'), medium);
      expect(fontSize(tester, 'line 3'), medium);
      expect(fontSize(tester, 'line 5'), medium);
    });

    testWidgets('the current line stays at the 40% anchor on every change', (
      tester,
    ) async {
      await pump(tester, lyricsOnly: true);
      for (final (seconds, line) in [(5, 4), (20, 19), (33, 32)]) {
        await playAt(tester, Duration(seconds: seconds, milliseconds: 100));
        expect(isCurrent(tester, 'line $line'), isTrue);
        // The anchor places the line's leading edge at 40% of the free space,
        // so its center is 40% down plus a tenth of its own height.
        final extent = tester
            .getSize(
              find.ancestor(
                of: find.text('line $line'),
                matching: find.byType(LyricsLine),
              ),
            )
            .height;
        expect(
          centerY(tester, 'line $line'),
          closeTo(400 * lyricsAnchor + extent * (0.5 - lyricsAnchor), 1),
        );
      }
    });
  });

  testWidgets('without the lyrics-only override lines keep headlineSmall', (
    tester,
  ) async {
    await pump(tester);
    final small = Theme.of(tester.element(find.byType(SyncedLyricsView)))
        .textTheme
        .headlineSmall!
        .fontSize;
    expect(styleOf(tester, 'line 3').fontSize, small);
  });
}
