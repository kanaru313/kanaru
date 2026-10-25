import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_now_playing.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_album_line.dart';
import 'package:kanaru/features/player/now_playing/now_playing_artwork.dart';
import 'package:kanaru/features/player/now_playing/now_playing_cover_only_body.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_body_harness.dart';

void main() {
  final h = BodyHarness();
  final cover = find.byType(NowPlayingArtwork);
  final body = find.byType(NowPlayingCoverOnlyBody);
  const album = NowPlayingAlbum(title: 'Blue Album', key: null);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    double textScale = 1,
    bool reduceMotion = true,
    bool withAlbum = true,
    List<Track>? tracks,
    FutureOr<NowPlayingAlbum?>? albumResult,
  }) => h.pump(
    tester,
    size: size,
    textScale: textScale,
    reduceMotion: reduceMotion,
    tracks: tracks,
    overrides: [
      nowPlayingAlbumProvider.overrideWith(
        (ref) async => albumResult ?? (withAlbum ? album : null),
      ),
    ],
    body: (chrome) => NowPlayingCoverOnlyBody(chrome: chrome),
  );

  /// The overlay's fade, the nearest one around the seek slot.
  double overlayOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byType(NowPlayingSeekSlot),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  group('cover', () {
    testWidgets('is centered', (tester) async {
      await pump(tester);
      expect(tester.getRect(cover).center.dx, 640);
      final side = tester.getSize(cover);
      expect(side.width, side.height);
      expect(side.width, greaterThan(300));
    });

    testWidgets('is as large as the height allows', (tester) async {
      await pump(tester, size: const Size(1920, 1080));
      final tall = tester.getSize(cover).width;
      tester.view.physicalSize = const Size(1920, 800);
      await tester.pumpAndSettle();
      expect(tester.getSize(cover).width, lessThan(tall));
    });

    testWidgets('is bounded by the width of a narrow window', (tester) async {
      await pump(tester, size: const Size(720, 1400));
      expect(tester.getSize(cover).width, 720 - 64);
    });

    testWidgets('keeps its rect when the controls hide and show', (
      tester,
    ) async {
      await pump(tester, reduceMotion: false);
      final shown = tester.getRect(cover);

      await h.hide(tester);
      expect(overlayOpacity(tester), 0);
      expect(tester.getRect(cover), shown);

      await h.show(tester);
      expect(overlayOpacity(tester), 1);
      expect(tester.getRect(cover), shown);
    });

    testWidgets('keeps its rect when the title wraps to two lines', (
      tester,
    ) async {
      await pump(tester);
      final oneLine = tester.getRect(cover);
      final pause = tester.getRect(find.byTooltip('Pause'));

      await h.player.next();
      await tester.pumpAndSettle();

      expect(find.textContaining('A very long title'), findsOneWidget);
      expect(tester.getRect(cover), oneLine);
      expect(tester.getRect(find.byTooltip('Pause')), pause);
    });

    testWidgets('keeps its rect when the album arrives late', (tester) async {
      final late = Completer<NowPlayingAlbum?>();
      await pump(tester, albumResult: late.future);
      final before = tester.getRect(cover);
      expect(find.text('Blue Album'), findsNothing);

      late.complete(album);
      await tester.pumpAndSettle();

      expect(find.text('Blue Album'), findsOneWidget);
      expect(tester.getRect(cover), before);
    });
  });

  group('text', () {
    testWidgets('title and artist · album show', (tester) async {
      await pump(tester);
      expect(find.text('Short'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
      expect(find.text('Blue Album'), findsOneWidget);
      expect(find.text('·'), findsOneWidget);
    });

    testWidgets('stays visible while the controls are hidden', (tester) async {
      await pump(tester, reduceMotion: false);
      await h.hide(tester);

      expect(overlayOpacity(tester), 0);
      for (final text in ['Short', 'Ann', 'Blue Album']) {
        expect(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedOpacity),
          ),
          findsNothing,
          reason: '$text is not inside the fading overlay',
        );
      }
    });

    testWidgets('no separator without an album', (tester) async {
      await pump(tester, withAlbum: false);
      expect(find.text('Ann'), findsOneWidget);
      expect(find.text('·'), findsNothing);
    });

    testWidgets('no separator without an artist', (tester) async {
      await pump(
        tester,
        tracks: [const Track(uri: '/music/none.flac', title: 'Nameless')],
      );
      expect(find.text('Blue Album'), findsOneWidget);
      expect(find.text('·'), findsNothing);
    });

    testWidgets('a long title takes at most two lines', (tester) async {
      await pump(tester);
      await h.player.next();
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.textContaining('A very long'));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('overlay', () {
    testWidgets('has the seek slot, times and three controls', (tester) async {
      await pump(tester);
      expect(find.byType(SeekBar), findsOneWidget);
      expect(find.byType(NowPlayingSeekSlot), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      for (final tip in ['Previous', 'Pause', 'Next']) {
        expect(find.byTooltip(tip), findsOneWidget);
      }
      expect(find.byTooltip('Shuffle'), findsNothing);
      final pause = tester.getRect(find.byTooltip('Pause'));
      expect(pause.center.dx, closeTo(640, 1));
      expect(pause.top, greaterThan(tester.getRect(cover).bottom));
    });

    testWidgets('is at most 560 px wide', (tester) async {
      await pump(tester, size: const Size(1920, 1080));
      expect(tester.getSize(find.byType(SeekBar)).width, 560);
    });

    testWidgets('the pointer on it keeps the chrome shown', (tester) async {
      await pump(tester);
      await h.expectPointerPins(tester, find.byTooltip('Pause'));
    });

    testWidgets('hidden, it schedules no frames on position ticks', (
      tester,
    ) async {
      await pump(tester, reduceMotion: false);
      await h.hide(tester);
      expect(overlayOpacity(tester), 0);
      await h.expectMutedWhileHidden(tester);
    });

    testWidgets('hidden with reduced motion, it schedules no frames', (
      tester,
    ) async {
      await pump(tester);
      await h.hide(tester);
      expect(overlayOpacity(tester), 0);
      await h.expectMutedWhileHidden(tester);
    });
  });

  group('fit', () {
    for (final (size, scale) in [
      (const Size(720, 720), 1.0),
      (const Size(1280, 800), 1.0),
      (const Size(1920, 1080), 1.0),
      (const Size(2560, 1440), 1.0),
      (const Size(720, 720), 1.5),
      (const Size(1280, 800), 1.5),
    ]) {
      testWidgets(
        'fits ${size.width.toInt()}x${size.height.toInt()} at $scale',
        (tester) async {
          await pump(tester, size: size, textScale: scale);
          await h.player.next();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.descendant(of: body, matching: find.byType(Scrollable)),
            findsNothing,
          );
          final pause = tester.getRect(find.byTooltip('Pause'));
          expect(pause.bottom, lessThanOrEqualTo(size.height));
          expect(tester.getRect(cover).top, greaterThanOrEqualTo(0));
        },
      );
    }
  });

  group('seek bar style', () {
    testWidgets('turning the waveform off makes the cover bigger', (
      tester,
    ) async {
      await pump(tester);
      final before = tester.getSize(cover).height;
      expect(tester.getSize(find.byType(NowPlayingSeekSlot)).height, 48);

      h.container
          .read(settingsProvider.notifier)
          .setDisplay(const DisplayPrefs(waveformSeekBar: false));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(NowPlayingSeekSlot)).height, 24);
      expect(tester.getSize(cover).height, closeTo(before + 24, 0.5));
      expect(tester.takeException(), isNull);
    });
  });
}
