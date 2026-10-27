import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show PlaysCompanion;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_day_header.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:material_ui/material_ui.dart';

import 'history_test_harness.dart';

DateTime _at(int day, [int hour = 9, int minute = 0, int month = 10]) =>
    DateTime(2026, month, day, hour, minute);

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

String? _current(LibraryHarness h) =>
    h.container.read(playerServiceProvider).queue.current?.uri;

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  group('days and rows', () {
    historyTestWidgets(
      'headers show the date and the distinct songs of the day',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [song('A'), song('B'), song('C')],
          plays: [
            ('A', _at(22, 20)),
            ('A', _at(23, 8)),
            ('A', _at(23, 9)),
            ('B', _at(23, 10, 30)),
            ('C', _at(20, 8, 15)),
          ],
        );

        // A played twice on the 23rd counts once: three plays, two songs.
        expect(listText('Oct 23, 2026 • 2 songs'), findsOneWidget);
        expect(listText('Oct 22, 2026 • 1 song'), findsOneWidget);
        expect(listText('Oct 20, 2026 • 1 song'), findsOneWidget);
        expect(find.text('Today'), findsNothing);
        expect(find.text('Yesterday'), findsNothing);
        // Newest first: the 23rd's rows, then the 22nd, then the 20th.
        double top(Finder finder) => tester.getTopLeft(finder).dy;
        expect(
          top(find.text('B')),
          lessThan(top(listText('Oct 22, 2026 • 1 song'))),
        );
        expect(
          top(listText('Oct 22, 2026 • 1 song')),
          lessThan(top(listText('Oct 20, 2026 • 1 song'))),
        );
        // Every line is one song row tall; the bar sits at the bottom of its
        // header line.
        final line = lineExtentOf(tester);
        final bar = barHeightOf(tester);
        final listTop = tester.getTopLeft(find.byType(HistoryTimelineView)).dy;
        final barBox = find.ancestor(
          of: listText('Oct 23, 2026 • 2 songs'),
          matching: find.byType(HistoryDayBar),
        );
        expect(tester.getSize(barBox).height, bar);
        expect(tester.getBottomLeft(barBox).dy - listTop, line);
      },
    );

    historyTestWidgets('the menu button is flush right on every day bar', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B'), song('C')],
        plays: [('A', _at(23, 8)), ('B', _at(23, 10)), ('C', _at(5, 8, 15, 9))],
      );

      // Two bars whose labels differ in length.
      final bars = find.byType(HistoryDayBar);
      expect(bars, findsNWidgets(2));
      final buttons = [
        for (var i = 0; i < 2; i++)
          find.descendant(of: bars.at(i), matching: find.byType(IconButton)),
      ];
      expect(listText('Oct 23, 2026 • 2 songs'), findsOneWidget);
      expect(listText('Sep 5, 2026 • 1 song'), findsOneWidget);
      final right0 = tester.getTopRight(buttons[0]).dx;
      final right1 = tester.getTopRight(buttons[1]).dx;
      expect(right0, right1);
      // The bar's right padding is 16.
      expect(tester.getTopRight(bars.at(0)).dx - right0, 16);
    });

    historyTestWidgets('a row has the Nth listen badge and the time', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', _at(22, 20)), ('A', _at(23, 9)), ('B', _at(23, 14, 5))],
      );

      // A's plays are its 1st (yesterday) and 2nd; B's only one.
      expect(find.text('#1'), findsNWidgets(2));
      expect(find.text('#2'), findsOneWidget);
      expect(find.byTooltip('Listen number 2'), findsOneWidget);
      expect(find.text('Oct 23, 2026 - 2:05 PM'), findsOneWidget);
      expect(find.text('Oct 23, 2026 - 9:00 AM'), findsOneWidget);
      expect(find.text('Oct 22, 2026 - 8:00 PM'), findsOneWidget);
    });

    historyTestWidgets('the time follows the 24 hour setting', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 14, 5))],
      );

      expect(find.text('Oct 23, 2026 - 14:05'), findsOneWidget);
    });

    historyTestWidgets(
      'a song gone from the library shows its file name, dimmed',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [song('A')],
          plays: [('A', _at(23, 9)), ('gone', _at(23, 10))],
        );

        expect(find.text('gone.flac'), findsOneWidget);
        expect(find.text('Not in library'), findsOneWidget);
        expect(find.text('Oct 23, 2026 - 10:00 AM'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        Finder opacities(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(HistoryPlayRowTile),
          ),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacities('gone.flac')).opacity, 0.6);
        expect(opacities('A'), findsNothing);
      },
    );
  });

  group('tapping a row', () {
    final plays = [
      ('A', _at(23, 8)),
      ('B', _at(23, 9)),
      ('A', _at(23, 10)),
      ('C', _at(23, 11)),
      ('Z', _at(22, 11)),
    ];

    historyTestWidgets(
      'queues the songs of that day once each, from the tapped',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [song('A'), song('B'), song('C'), song('Z')],
          plays: plays,
        );

        // Shown as C, A, B, A: the queue is C, A, B, starting at B.
        await tester.tap(find.text('B'));
        await tester.pump();

        expect(_queue(h), ['/m/C.flac', '/m/A.flac', '/m/B.flac']);
        expect(_current(h), '/m/B.flac');
      },
    );

    historyTestWidgets('a repeated song starts at its first place', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B'), song('C'), song('Z')],
        plays: plays,
      );

      // The A shown last is the 08:00 one.
      await tester.tap(find.text('A').last);
      await tester.pump();

      expect(_queue(h), ['/m/C.flac', '/m/A.flac', '/m/B.flac']);
      expect(_current(h), '/m/A.flac');
    });

    historyTestWidgets(
      'songs gone from the library are skipped and do not play',
      (tester) async {
        // A is not in the library.
        await openHistory(
          tester,
          h,
          tracks: [song('B'), song('C'), song('Z')],
          plays: plays,
        );

        await tester.tap(find.text('B'));
        await tester.pump();
        expect(_queue(h), ['/m/C.flac', '/m/B.flac']);
        expect(_current(h), '/m/B.flac');

        await tester.tap(find.text('A.flac').first);
        await tester.pump();
        // Nothing changed: the missing song is not playable, and no track was
        // ever made from the path a play remembers.
        expect(_queue(h), ['/m/C.flac', '/m/B.flac']);
        expect(h.backend.calls.where((c) => c.contains('A.flac')), isEmpty);
      },
    );
  });

  group('row menu', () {
    historyTestWidgets(
      'Play next queues the song of the row it was opened on',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [song('A'), song('B')],
          plays: [('A', _at(23, 9)), ('B', _at(23, 10))],
        );

        await tester.tap(find.text('B'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play next'));
        await tester.pumpAndSettle();

        // B is the newest, the first row.
        expect(_queue(h), ['/m/B.flac']);
      },
    );

    historyTestWidgets('a right click opens the menu', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9))],
      );

      await tester.tap(find.text('A'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Remove from history'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Song history'), findsOneWidget);
    });

    historyTestWidgets('a long press opens the menu', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9))],
      );

      await tester.longPress(find.text('A'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from history'), findsOneWidget);
    });

    historyTestWidgets('rows have no more button', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9))],
      );

      expect(find.byTooltip('More'), findsNothing);
    });

    historyTestWidgets('a song gone from the library cannot be queued', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23, 9))]);

      await tester.tap(find.text('gone.flac'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      for (final label in ['Play next', 'Add to queue', 'Add to playlist…']) {
        final item = tester.widget<PopupMenuItem<Object?>>(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          ),
        );
        expect(item.enabled, isFalse, reason: label);
      }
      expect(find.text('Remove from history'), findsOneWidget);
    });

    historyTestWidgets('the Menu key on a song gone from the library opens '
        'its menu', (tester) async {
      await openHistory(tester, h, plays: [('gone', _at(23, 9))]);

      // The row content is the focus stop: the nearest Focus above the row
      // view, not the one above its text.
      Focus.of(tester.element(find.byType(SongRowView))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(find.text('Remove from history'), findsOneWidget);
    });
  });

  group('pinned bar', () {
    final plays = [
      for (var i = 0; i < 12; i++) ('S$i', _at(23, i)),
      for (var i = 0; i < 14; i++) ('Y$i', _at(22, i)),
    ];
    final tracks = [
      for (var i = 0; i < 12; i++) song('S$i'),
      for (var i = 0; i < 14; i++) song('Y$i'),
    ];
    const today = 'Oct 23, 2026 • 12 songs';
    const yesterday = 'Oct 22, 2026 • 14 songs';

    /// Offset at which the bar of the day whose header is line [line] is at
    /// the top.
    double barAt(WidgetTester tester, int line) =>
        line * lineExtentOf(tester) +
        lineExtentOf(tester) -
        barHeightOf(tester);

    historyTestWidgets('shows the day at the top while its rows scroll', (
      tester,
    ) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      // The first bar is still in the list: nothing is pinned.
      expect(stickyText(today), findsNothing);
      expect(listText(today), findsOneWidget);

      // Inside today's rows: its own bar is off screen, the pinned one shows
      // it.
      await scrollTimelineTo(tester, lineExtentOf(tester) * 5 + 10);
      expect(listText(today), findsNothing);
      expect(stickyText(today), findsOneWidget);

      // Inside yesterday: the pinned bar is its bar.
      await scrollTimelineTo(tester, lineExtentOf(tester) * 13 + 60);
      expect(stickyText(today), findsNothing);
      expect(stickyText(yesterday), findsOneWidget);
    });

    historyTestWidgets('the next bar pushes the pinned one up', (tester) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      final bar = barHeightOf(tester);
      final next = barAt(tester, 13);

      // Half a bar before the next one arrives.
      await scrollTimelineTo(tester, next - bar / 2);
      expect(stickyText(today), findsOneWidget);
      final pinned = tester.getTopLeft(stickyText(today)).dy;
      await scrollTimelineTo(tester, next - bar / 4);
      expect(tester.getTopLeft(stickyText(today)).dy, lessThan(pinned));
      // The incoming bar is in the list below, never overlapping the pinned
      // one.
      final incoming = tester.getTopLeft(
        find.ancestor(
          of: listText(yesterday),
          matching: find.byType(HistoryDayBar),
        ),
      );
      final pinnedBar = find.ancestor(
        of: stickyText(today),
        matching: find.byType(HistoryDayBar),
      );
      expect(incoming.dy, closeTo(tester.getBottomLeft(pinnedBar).dy, 0.01));

      await scrollTimelineTo(tester, next);
      expect(stickyText(yesterday), findsOneWidget);
      final listTop = tester.getTopLeft(find.byType(HistoryTimelineView)).dy;
      expect(
        tester.getTopLeft(stickyText(yesterday)).dy - listTop,
        lessThan(bar),
      );
    });

    historyTestWidgets(
      'the first row below the bar is the one that is tapped',
      (tester) async {
        await openHistory(tester, h, tracks: tracks, plays: plays);
        await scrollTimelineTo(tester, lineExtentOf(tester) * 5 + 10);

        // Line 6 is today's row 5, S6, drawn from y = 70; its title is below
        // the pinned bar.
        await tester.tap(find.text('S6'));
        await tester.pump();

        expect(_current(h), '/m/S6.flac');
      },
    );

    historyTestWidgets('the wheel over the pinned bar scrolls the list', (
      tester,
    ) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      await scrollTimelineTo(tester, lineExtentOf(tester) * 5);
      final before = timelineOffset(tester);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(stickyText(today)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pump();

      expect(timelineOffset(tester), before + 100);
    });

    historyTestWidgets('a touchpad pan over the pinned bar scrolls the list', (
      tester,
    ) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      await scrollTimelineTo(tester, lineExtentOf(tester) * 5);
      final before = timelineOffset(tester);

      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final at = tester.getCenter(stickyText(today));
      await tester.sendEventToBinding(pad.panZoomStart(at));
      await tester.sendEventToBinding(
        pad.panZoomUpdate(at, pan: const Offset(0, -60)),
      );
      await tester.pump();
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(timelineOffset(tester), before + 60);
    });
  });

  group('live updates', () {
    historyTestWidgets('a new play at the top shows at once', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', _at(23, 9))],
      );

      await seedPlays(tester, h, [('B', _at(23, 11))]);
      await settleHistory(tester);

      expect(find.text('B'), findsOneWidget);
      expect(listText('Oct 23, 2026 • 2 songs'), findsOneWidget);
    });

    historyTestWidgets(
      'a new play is held back while scrolled, shown on return',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
          plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
        );
        await scrollTimelineTo(tester, lineExtentOf(tester) * 6);
        final before = tester.getTopLeft(find.text('S20')).dy;

        await seedPlays(tester, h, [('New', _at(23, 11, 59))]);
        await settleHistory(tester);

        expect(find.text('New'), findsNothing);
        expect(timelineOffset(tester), lineExtentOf(tester) * 6);
        expect(tester.getTopLeft(find.text('S20')).dy, before);

        await scrollTimelineTo(tester, 0);
        expect(find.text('New'), findsOneWidget);
        expect(listText('Oct 23, 2026 • 31 songs'), findsOneWidget);
      },
    );

    historyTestWidgets(
      'a day read again while a play is held keeps the shown rows',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
          plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
        );
        await scrollTimelineTo(tester, lineExtentOf(tester) * 6);
        await seedPlays(tester, h, [('New', _at(23, 11, 59))]);
        await settleHistory(tester);

        // A scan makes the page read the rows of the day again.
        await tester.runAsync(
          () => h.db.customUpdate(
            "UPDATE tracks SET title = 'T' || title WHERE path = '/m/S0.flac'",
            updates: {h.db.tracks},
          ),
        );
        await settleHistory(tester);

        // Still the 30 plays the header counts: the held one is not drawn and
        // the oldest one is not pushed out.
        expect(find.text('New'), findsNothing);
        expect(timelineOffset(tester), lineExtentOf(tester) * 6);
        await scrollTimelineTo(tester, lineExtentOf(tester) * 28);
        expect(find.text('TS0'), findsOneWidget);
        expect(find.text('New'), findsNothing);
        expect(listText('Oct 23, 2026 • 31 songs'), findsNothing);

        await scrollTimelineTo(tester, 0);
        expect(find.text('New'), findsOneWidget);
        expect(listText('Oct 23, 2026 • 31 songs'), findsOneWidget);
        await scrollTimelineTo(tester, lineExtentOf(tester) * 28);
        expect(find.text('TS0'), findsOneWidget);
      },
    );

    historyTestWidgets(
      'a day read just before a play is held is cut to its count',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
          plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
        );
        await scrollTimelineTo(tester, lineExtentOf(tester) * 6);

        // The scan reads the day again with the new play in it, before the
        // plays debounce ends and the page decides to hold the counts back.
        await tester.runAsync(() async {
          await h.db
              .into(h.db.plays)
              .insert(
                PlaysCompanion.insert(
                  path: '/m/New.flac',
                  playedAt: _at(23, 11, 59).millisecondsSinceEpoch,
                ),
              );
          await h.db.customUpdate(
            "UPDATE tracks SET title = 'T' || title WHERE path = '/m/S0.flac'",
            updates: {h.db.tracks},
          );
        });
        await settleHistory(tester);

        expect(find.text('New'), findsNothing);
        await scrollTimelineTo(tester, lineExtentOf(tester) * 28);
        expect(find.text('TS0'), findsOneWidget);
        expect(listText('Oct 23, 2026 • 31 songs'), findsNothing);
      },
    );

    historyTestWidgets('a removal shows at once even when scrolled', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [for (var i = 0; i < 30; i++) song('S$i')],
        plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
      );
      await scrollTimelineTo(tester, lineExtentOf(tester) * 6);

      await tester.runAsync(
        () => (h.db.delete(
          h.db.plays,
        )..where((p) => p.path.equals('/m/S20.flac'))).go(),
      );
      await settleHistory(tester);

      expect(find.text('S20'), findsNothing);
      expect(listText('Oct 23, 2026 • 29 songs'), findsNothing);
      await scrollTimelineTo(tester, 0);
      expect(listText('Oct 23, 2026 • 29 songs'), findsOneWidget);
    });

    historyTestWidgets('a rescan that changes tags updates the rows', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9))],
      );

      await tester.runAsync(
        () => h.db.customUpdate(
          "UPDATE tracks SET title = 'Renamed' WHERE path = '/m/A.flac'",
          updates: {h.db.tracks},
        ),
      );
      await settleHistory(tester);

      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    historyTestWidgets('clearing the history while open shows the empty page', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9))],
      );

      await tester.runAsync(() => h.db.delete(h.db.plays).go());
      await settleHistory(tester);

      expect(find.text('Songs you play will show up here.'), findsOneWidget);
      expect(find.byType(HistoryPlayRowTile), findsNothing);
    });
  });
}
