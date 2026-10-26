import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/plain_lyrics_view.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_only_body.dart';
import 'package:kanaru/features/player/now_playing/now_playing_lyrics_strip.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_body_harness.dart';

void main() {
  final h = BodyHarness();
  const lyricsKey = ValueKey('lyrics');
  final strip = find.byType(NowPlayingLyricsStrip);
  var showSplitCalls = 0;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    double textScale = 1,
    bool reduceMotion = true,
    Widget lyrics = const SizedBox.expand(key: lyricsKey),
  }) {
    showSplitCalls = 0;
    return h.pump(
      tester,
      size: size,
      textScale: textScale,
      reduceMotion: reduceMotion,
      body: (chrome) => NowPlayingLyricsOnlyBody(
        lyrics: lyrics,
        chrome: chrome,
        onShowSplit: () => showSplitCalls++,
      ),
    );
  }

  double stripOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: strip, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;

  group('lyrics column', () {
    testWidgets('is at most 800 px wide and centered', (tester) async {
      await pump(tester);
      final rect = tester.getRect(find.byKey(lyricsKey));
      expect(rect.width, 800);
      expect(rect.center.dx, 640);
      expect(rect.height, 800);
    });

    testWidgets('takes the whole width of a narrower window', (tester) async {
      await pump(tester, size: const Size(720, 720));
      expect(tester.getRect(find.byKey(lyricsKey)).width, 720);
    });

    testWidgets('never moves when the strip shows or hides', (tester) async {
      await pump(tester, reduceMotion: false);
      final shown = tester.getRect(find.byKey(lyricsKey));

      await h.hide(tester);
      expect(stripOpacity(tester), 0);
      expect(tester.getRect(find.byKey(lyricsKey)), shown);

      await h.show(tester);
      expect(stripOpacity(tester), 1);
      expect(tester.getRect(find.byKey(lyricsKey)), shown);
    });

    testWidgets('plain lyrics can scroll their last line clear of the strip', (
      tester,
    ) async {
      final lyrics = Lyrics(
        lines: [
          for (var i = 0; i < 60; i++) LyricLine(Duration.zero, 'row $i'),
        ],
        synced: false,
        source: LyricsSource.sidecar,
      );
      await pump(tester, lyrics: PlainLyricsView(lyrics: lyrics));
      await tester.drag(find.byType(PlainLyricsView), const Offset(0, -20000));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('row 59')).bottom,
        lessThanOrEqualTo(tester.getRect(strip).top),
      );
    });
  });

  group('strip', () {
    testWidgets('shows the cover, title, artist, seek track and controls', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.descendant(of: strip, matching: find.byType(TrackArtwork)),
        findsOneWidget,
      );
      expect(find.text('Short'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
      expect(
        find.descendant(of: strip, matching: find.byType(SeekBar)),
        findsOneWidget,
      );
      expect(find.byType(NowPlayingSeekSlot), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      for (final tip in ['Previous', 'Pause', 'Next']) {
        expect(find.byTooltip(tip), findsOneWidget);
      }
      expect(find.byTooltip('Shuffle'), findsNothing);
      expect(find.byTooltip('Add to favorites'), findsNothing);
    });

    testWidgets('overlays the bottom of the lyrics on a gradient', (
      tester,
    ) async {
      await pump(tester);
      final stripRect = tester.getRect(strip);
      final lyricsRect = tester.getRect(find.byKey(lyricsKey));
      expect(stripRect.bottom, lyricsRect.bottom);
      expect(stripRect.top, lessThan(lyricsRect.bottom));
      expect(stripRect.width, 1280);
      expect(stripRect.height, 76);

      final box = tester.widget<DecoratedBox>(
        find.descendant(of: strip, matching: find.byType(DecoratedBox)).first,
      );
      final gradient = (box.decoration as BoxDecoration).gradient!;
      expect(gradient, isA<LinearGradient>());
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors.last.a, closeTo(0.85, 0.01));
    });

    testWidgets('pressing the cover asks for the split view', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Split view'));
      await tester.pump();
      expect(showSplitCalls, 1);
    });

    testWidgets('a long title is ellipsized within 240 px', (tester) async {
      await pump(tester);
      await h.player.next();
      await tester.pumpAndSettle();

      final title = find.textContaining('A very long title');
      expect(title, findsOneWidget);
      expect(tester.getSize(title).width, lessThanOrEqualTo(240));
      final text = tester.widget<Text>(title);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('the play button is square, not squashed by the strip', (
      tester,
    ) async {
      for (final scale in [1.0, 1.5]) {
        await pump(tester, size: const Size(720, 720), textScale: scale);
        final size = tester.getSize(
          find.ancestor(
            of: find.byTooltip('Pause'),
            matching: find.byType(IconButton),
          ),
        );
        expect(size.width, size.height, reason: 'scale $scale');
        expect(size.height, 52);
      }
    });

    testWidgets('the cover shows ink on top of the artwork', (tester) async {
      await pump(tester);
      final cover = find.descendant(
        of: strip,
        matching: find.byType(TrackArtwork),
      );
      final ink = find.descendant(of: strip, matching: find.byType(InkWell));
      expect(tester.getRect(ink.first), tester.getRect(cover));
    });

    testWidgets('the pointer on the strip keeps the chrome shown', (
      tester,
    ) async {
      await pump(tester);
      await h.expectPointerPins(tester, find.byTooltip('Pause'));
    });

    testWidgets('hidden, it is not clickable', (tester) async {
      await pump(tester);
      await h.hide(tester);
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: strip, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('hidden, it schedules no frames on position ticks', (
      tester,
    ) async {
      await pump(tester, reduceMotion: false);
      await h.hide(tester);
      expect(stripOpacity(tester), 0);
      await h.expectMutedWhileHidden(tester);
    });

    testWidgets('hidden with reduced motion, it schedules no frames', (
      tester,
    ) async {
      await pump(tester);
      await h.hide(tester);
      expect(stripOpacity(tester), 0);
      await h.expectMutedWhileHidden(tester);
    });
  });

  group('seek slot', () {
    double trackWidth(WidgetTester tester) =>
        tester.getSize(find.byType(NowPlayingSeekSlot)).width;

    for (final (size, scale) in [
      (const Size(720, 720), 1.0),
      (const Size(720, 720), 1.5),
      (const Size(1280, 800), 1.0),
      (const Size(1280, 800), 1.5),
    ]) {
      testWidgets(
        'is at least 120 px wide at ${size.width.toInt()} px, text x$scale',
        (tester) async {
          await pump(tester, size: size, textScale: scale);
          await h.player.next();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(trackWidth(tester), greaterThanOrEqualTo(120));
        },
      );
    }
  });

  group('fit', () {
    for (final size in [
      const Size(720, 720),
      const Size(1280, 800),
      const Size(1920, 1080),
    ]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(strip).right, size.width);
      });
    }

    testWidgets('fits large text at 720 px', (tester) async {
      await pump(tester, size: const Size(720, 720), textScale: 1.5);
      await h.player.next();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(strip).height, greaterThan(76));
      expect(tester.getRect(strip).bottom, 720);
      final pause = tester.getRect(find.byTooltip('Pause'));
      expect(pause.bottom, lessThanOrEqualTo(720));
      expect(pause.right, lessThanOrEqualTo(720));
    });
  });

  group('seek bar style', () {
    testWidgets('turning the waveform off keeps the strip, slot 24 px', (
      tester,
    ) async {
      await pump(tester);
      final before = tester.getSize(strip).height;
      expect(tester.getSize(find.byType(NowPlayingSeekSlot)).height, 48);

      h.container
          .read(settingsProvider.notifier)
          .setDisplay(const DisplayPrefs(waveformSeekBar: false));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(NowPlayingSeekSlot)).height, 24);
      expect(tester.getSize(strip).height, before);
      expect(tester.takeException(), isNull);
    });
  });
}
