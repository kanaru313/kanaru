import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_now_playing.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_album_line.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/now_playing/now_playing_split_geometry.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_info.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_split_harness.dart';

void main() {
  final h = SplitHarness();
  final column = splitColumn;
  final cover = splitCover;
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    List<Override> overrides = const [],
    double textScale = 1,
  }) => h.pump(tester, size: size, overrides: overrides, textScale: textScale);

  group('geometry', () {
    test('the column takes 42% of the body, clamped to 300 to 600', () {
      expect(splitColumnWidth(1280), closeTo(537.6, 0.01));
      expect(splitColumnWidth(720), closeTo(302.4, 0.01));
      expect(splitColumnWidth(600), 300);
      expect(splitColumnWidth(2560), 600);
    });

    testWidgets('the column is 42% of the body at 1280', (tester) async {
      await pump(tester);
      expect(tester.getSize(column).width, closeTo(537.6, 0.5));
      expect(tester.getRect(column).left, 0);
    });

    testWidgets('the column is near its minimum at 720', (tester) async {
      await pump(tester, size: const Size(720, 800));
      expect(tester.getSize(column).width, closeTo(302.4, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the column is clamped at 600 on a wide window', (
      tester,
    ) async {
      await pump(tester, size: const Size(2560, 1440));
      expect(tester.getSize(column).width, 600);
    });

    testWidgets('the cover is at most 500 px', (tester) async {
      await pump(tester, size: const Size(1920, 1000));
      expect(tester.getSize(cover), const Size(500, 500));
    });

    testWidgets('a short window bounds the cover by its height', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 720));
      final size = tester.getSize(cover);
      expect(size.width, lessThan(500));
      expect(size.width, greaterThan(200));
      // Everything fits under the header without scrolling or overflowing.
      expect(
        tester.getRect(find.byTooltip('Pause')).bottom,
        lessThanOrEqualTo(720),
      );
      expect(tester.takeException(), isNull);
    });

    for (final height in [480.0, 560.0]) {
      testWidgets('a long title and the album fit $height px high', (
        tester,
      ) async {
        final album = Completer<NowPlayingAlbum?>()
          ..complete(const NowPlayingAlbum(title: 'Blue Album', key: null));
        await pump(
          tester,
          size: Size(1280, height),
          overrides: [
            nowPlayingAlbumProvider.overrideWith((ref) => album.future),
          ],
        );
        await h.player.next();
        await tester.pumpAndSettle();

        expect(find.text('Blue Album'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a window shorter than the smallest cover scales down', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 300));

      expect(tester.takeException(), isNull);
      final cover = tester.getRect(splitCover);
      expect(cover.width, lessThan(96));
      expect(tester.getRect(find.byTooltip('Pause')).bottom, lessThan(300));
    });

    testWidgets('the cover has no scrollable around it', (tester) async {
      await pump(tester);
      expect(
        find.ancestor(of: cover, matching: find.byType(Scrollable)),
        findsNothing,
      );
    });

    testWidgets('fits large text', (tester) async {
      await pump(tester, size: const Size(720, 720), textScale: 1.5);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byTooltip('Pause')).bottom,
        lessThanOrEqualTo(720),
      );
    });

    testWidgets('the cover stays put when the title wraps differently', (
      tester,
    ) async {
      await pump(tester);
      final shortTitle = tester.getRect(cover);
      final pause = tester.getRect(find.byTooltip('Pause'));

      await h.player.next();
      await tester.pumpAndSettle();

      expect(find.textContaining('A very long title'), findsWidgets);
      expect(tester.getRect(cover), shortTitle);
      expect(tester.getRect(find.byTooltip('Pause')), pause);
    });

    testWidgets('the cover stays put when the album arrives late', (
      tester,
    ) async {
      final album = Completer<NowPlayingAlbum?>();
      await pump(
        tester,
        overrides: [
          nowPlayingAlbumProvider.overrideWith((ref) => album.future),
        ],
      );
      final before = tester.getRect(cover);
      final pause = tester.getRect(find.byTooltip('Pause'));
      expect(find.text('Blue Album'), findsNothing);

      album.complete(const NowPlayingAlbum(title: 'Blue Album', key: null));
      await tester.pumpAndSettle();

      expect(find.text('Blue Album'), findsOneWidget);
      expect(tester.getRect(cover), before);
      expect(tester.getRect(find.byTooltip('Pause')), pause);
    });

    testWidgets('the title row has no buttons', (tester) async {
      await pump(tester);
      expect(
        find.descendant(
          of: find.byType(NowPlayingTitle),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
      // The only buttons in the column are the transport ones.
      expect(
        find.descendant(of: column, matching: find.byType(IconButton)),
        findsNWidgets(3),
      );
    });

    testWidgets('the seek slot is over the row of times and buttons', (
      tester,
    ) async {
      await pump(tester);
      final slot = tester.getRect(find.byType(NowPlayingSeekSlot));
      final pause = tester.getRect(find.byTooltip('Pause'));
      final elapsed = tester.getRect(
        find.descendant(of: column, matching: find.text('0:00')).first,
      );
      expect(slot.bottom, lessThanOrEqualTo(pause.top + 8));
      expect(elapsed.right, lessThan(tester.getCenter(column).dx));
      expect(elapsed.center.dy, closeTo(pause.center.dy, 2));
    });

    testWidgets('a pointer resting on the seek track keeps the cursor', (
      tester,
    ) async {
      await pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 700));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(NowPlayingSeekSlot)));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4));

      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.none),
      );
      final header = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byTooltip('Close Now Playing'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(header.opacity, 1);
    });
  });

  group('seek bar style', () {
    testWidgets('turning the waveform off gives 24 px to the cover', (
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
