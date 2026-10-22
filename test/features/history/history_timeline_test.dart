import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
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
    testWidgets('headers say Today, Yesterday or the date, with counts', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B'), song('C')],
        plays: [
          ('A', _at(22, 20)),
          ('A', _at(23, 9)),
          ('B', _at(23, 10, 30)),
          ('C', _at(20, 8, 15)),
        ],
      );

      expect(listText('Today'), findsOneWidget);
      expect(listText('2 listens'), findsOneWidget);
      expect(listText('Yesterday'), findsOneWidget);
      expect(listText('Tuesday, October 20, 2026'), findsOneWidget);
      expect(listText('1 listen'), findsNWidgets(2));
      // Newest first: today's two, yesterday's, then the 20th.
      double top(String title) => tester.getTopLeft(find.text(title)).dy;
      expect(top('B'), lessThan(top('Yesterday')));
      expect(top('Yesterday'), lessThan(top('Tuesday, October 20, 2026')));
    });

    testWidgets('a row has the Nth listen badge and the time', (tester) async {
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
      expect(find.text('2:05 PM'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
    });

    testWidgets('the time follows the 24 hour setting', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 14, 5))],
      );

      expect(find.text('14:05'), findsOneWidget);
    });

    testWidgets('a song gone from the library shows its file name, dimmed', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(23, 9)), ('gone', _at(23, 10))],
      );

      expect(find.text('gone.flac'), findsOneWidget);
      expect(find.text('Not in library'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      double opacityOf(String text) => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(text), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(opacityOf('gone.flac'), lessThan(1));
      expect(opacityOf('A'), 1);
    });
  });

  group('tapping a row', () {
    final plays = [
      ('A', _at(23, 8)),
      ('B', _at(23, 9)),
      ('A', _at(23, 10)),
      ('C', _at(23, 11)),
      ('Z', _at(22, 11)),
    ];

    testWidgets('queues the songs of that day once each, from the tapped', (
      tester,
    ) async {
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
    });

    testWidgets('a repeated song starts at its first place', (tester) async {
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

    testWidgets('songs gone from the library are skipped and do not play', (
      tester,
    ) async {
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
    });
  });

  group('row menu', () {
    testWidgets('Play next queues the song of the row it was opened on', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', _at(23, 9)), ('B', _at(23, 10))],
      );

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play next'));
      await tester.pumpAndSettle();

      // B is the newest, the first row.
      expect(_queue(h), ['/m/B.flac']);
    });

    testWidgets('a right click opens the menu too', (tester) async {
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
    });

    testWidgets('a song gone from the library cannot be queued', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23, 9))]);

      await tester.tap(find.byTooltip('More'));
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
  });

  group('sticky header', () {
    final plays = [
      for (var i = 0; i < 12; i++) ('S$i', _at(23, i)),
      for (var i = 0; i < 14; i++) ('Y$i', _at(22, i)),
    ];
    final tracks = [
      for (var i = 0; i < 12; i++) song('S$i'),
      for (var i = 0; i < 14; i++) song('Y$i'),
    ];

    testWidgets('shows the day at the top while its rows scroll', (
      tester,
    ) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      expect(stickyText('Today'), findsOneWidget);

      // Inside today's rows: its own header is off screen, the overlay
      // shows it.
      await scrollTimelineTo(tester, rowExtent * 5 + 10);
      expect(listText('Today'), findsNothing);
      expect(stickyText('Today'), findsOneWidget);

      // Inside yesterday: the overlay is its header.
      await scrollTimelineTo(tester, rowExtent * 13);
      expect(stickyText('Today'), findsNothing);
      expect(stickyText('Yesterday'), findsOneWidget);
    });

    testWidgets('the first row below the header is the one that is tapped', (
      tester,
    ) async {
      await openHistory(tester, h, tracks: tracks, plays: plays);
      await scrollTimelineTo(tester, rowExtent * 5 + 10);

      // Line 6 is today's row 5, S6, drawn from y = 54; its title is
      // below the sticky header.
      await tester.tap(find.text('S6'));
      await tester.pump();

      expect(_current(h), '/m/S6.flac');
    });
  });

  group('live updates', () {
    testWidgets('a new play at the top shows at once', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', _at(23, 9))],
      );

      await seedPlays(tester, h, [('B', _at(23, 11))]);
      await settleHistory(tester);

      expect(find.text('B'), findsOneWidget);
      expect(listText('2 listens'), findsOneWidget);
    });

    testWidgets('a new play is held back while scrolled, shown on return', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
        plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
      );
      await scrollTimelineTo(tester, rowExtent * 6);
      final before = tester.getTopLeft(find.text('S20')).dy;

      await seedPlays(tester, h, [('New', _at(23, 11, 59))]);
      await settleHistory(tester);

      expect(find.text('New'), findsNothing);
      expect(timelineOffset(tester), rowExtent * 6);
      expect(tester.getTopLeft(find.text('S20')).dy, before);

      await scrollTimelineTo(tester, 0);
      expect(find.text('New'), findsOneWidget);
      expect(listText('31 listens'), findsOneWidget);
    });

    testWidgets('a removal shows at once even when scrolled', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [for (var i = 0; i < 30; i++) song('S$i')],
        plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0, i))],
      );
      await scrollTimelineTo(tester, rowExtent * 6);

      await tester.runAsync(
        () => (h.db.delete(
          h.db.plays,
        )..where((p) => p.path.equals('/m/S20.flac'))).go(),
      );
      await settleHistory(tester);

      expect(find.text('S20'), findsNothing);
      expect(listText('29 listens'), findsNothing);
      await scrollTimelineTo(tester, 0);
      expect(listText('29 listens'), findsOneWidget);
    });

    testWidgets('a rescan that changes tags updates the rows', (tester) async {
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

    testWidgets('clearing the history while open shows the empty page', (
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
      expect(listText('Today'), findsNothing);
    });
  });
}
