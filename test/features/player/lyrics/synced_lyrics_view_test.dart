import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/lyrics_line.dart';
import 'package:kanaru/features/player/lyrics/synced_lyrics_view.dart';
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

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
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
          home: Scaffold(body: SyncedLyricsView(lyrics: _lyrics)),
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
}
