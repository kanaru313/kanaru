import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_day_header.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:material_ui/material_ui.dart';

import 'history_test_harness.dart';

DateTime _at(int day, int hour, [int month = 10, int year = 2026]) =>
    DateTime(year, month, day, hour);

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

String? _current(LibraryHarness h) =>
    h.container.read(playerServiceProvider).queue.current?.uri;

const _day23 = 'Oct 23, 2026 • 3 songs';
const _day22 = 'Oct 22, 2026 • 1 song';

Finder get _dayMenu => find.byTooltip('Day options');

/// Opens the menu of the first day bar on the page.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_dayMenu.first);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String label) => tester
    .widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    )
    .enabled;

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  /// The 23rd: gone (newest), A, B, A (oldest). The 22nd: Z.
  Future<void> open(WidgetTester tester) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('Z')],
    plays: [
      ('A', _at(23, 8)),
      ('B', _at(23, 9)),
      ('A', _at(23, 10)),
      ('gone', _at(23, 11)),
      ('Z', _at(22, 11)),
    ],
  );

  historyTestWidgets('the menu lists the five day actions', (tester) async {
    await open(tester);
    await _openMenu(tester);

    for (final label in [
      'Play all',
      'Play next',
      'Add to queue',
      'Create playlist from this day',
      "Remove this day's listens",
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(_enabled(tester, label), isTrue, reason: label);
    }
  });

  historyTestWidgets('Play all queues the songs as listed, once each', (
    tester,
  ) async {
    await open(tester);
    await _openMenu(tester);
    await _choose(tester, 'Play all');

    // Shown newest first as gone, A, B, A: the missing one is skipped and A
    // stays at its first place.
    expect(_queue(h), ['/m/A.flac', '/m/B.flac']);
    expect(_current(h), '/m/A.flac');
  });

  historyTestWidgets('Play next and Add to queue take the same songs', (
    tester,
  ) async {
    await open(tester);
    await _openMenu(tester);
    await _choose(tester, 'Play next');
    expect(_queue(h), ['/m/A.flac', '/m/B.flac']);

    await _openMenu(tester);
    await _choose(tester, 'Add to queue');
    expect(_queue(h), ['/m/A.flac', '/m/B.flac', '/m/A.flac', '/m/B.flac']);
  });

  historyTestWidgets('Create playlist is named after the day and keeps its '
      'distinct songs', (tester) async {
    await open(tester);
    await _openMenu(tester);
    await _choose(tester, 'Create playlist from this day');

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'History · Oct 23, 2026');

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleHistory(tester);

    final entries = await tester.runAsync(
      () => (h.db.select(
        h.db.playlistEntries,
      )..orderBy([(e) => OrderingTerm.asc(e.position)])).get(),
    );
    expect([for (final e in entries!) e.path], ['/m/A.flac', '/m/B.flac']);
    expect(
      find.text('Created playlist History · Oct 23, 2026'),
      findsOneWidget,
    );
  });

  historyTestWidgets('Remove empties the day; Undo brings it back', (
    tester,
  ) async {
    await open(tester);
    await _openMenu(tester);
    await _choose(tester, "Remove this day's listens");
    await settleHistory(tester);

    expect(listText(_day23), findsNothing);
    expect(listText(_day22), findsOneWidget);
    expect(find.text('Removed 4 listens from history'), findsOneWidget);
    final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
    expect(left!.map((p) => p.path), ['/m/Z.flac']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await settleHistory(tester);

    expect(listText(_day23), findsOneWidget);
    final back = await tester.runAsync(() => h.db.select(h.db.plays).get());
    expect(back, hasLength(5));
  });

  historyTestWidgets('Remove deletes the plays shown, not one recorded while '
      'the menu was open', (tester) async {
    await open(tester);
    await tester.tap(_dayMenu.first);
    await tester.pumpAndSettle();

    await seedPlays(tester, h, [('B', _at(23, 11))]);
    await _choose(tester, "Remove this day's listens");
    await settleHistory(tester);

    final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
    expect(left!.map((p) => p.path).toSet(), {'/m/Z.flac', '/m/B.flac'});
    expect(left, hasLength(2));
  });

  historyTestWidgets('Remove spares a play held back while scrolled away', (
    tester,
  ) async {
    await openHistory(
      tester,
      h,
      tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
      plays: [for (var i = 0; i < 30; i++) ('S$i', _at(23, 0))],
    );
    await scrollTimelineTo(tester, lineExtentOf(tester) * 6);
    await seedPlays(tester, h, [('New', _at(23, 11))]);
    await settleHistory(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(historyStickyHeaderKey),
        matching: _dayMenu,
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, "Remove this day's listens");
    await settleHistory(tester);

    // The page showed 30 plays: the one it held back is not deleted.
    final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
    expect(left!.map((p) => p.path), ['/m/New.flac']);
  });

  historyTestWidgets('a double click on the day button opens one menu', (
    tester,
  ) async {
    await open(tester);
    final button = tester.getCenter(_dayMenu.first);
    await tester.tapAt(button);
    await tester.tapAt(button);
    await tester.pumpAndSettle();

    expect(find.text('Play all'), findsOneWidget);
  });

  historyTestWidgets('the day button says which day it is for', (tester) async {
    await open(tester);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('Day options, Oct 23, 2026')),
      findsOneWidget,
    );
    expect(find.byTooltip('Day options'), findsWidgets);
    handle.dispose();
  });

  historyTestWidgets('a day of songs gone from the library keeps only Remove', (
    tester,
  ) async {
    await openHistory(tester, h, plays: [('gone', _at(23, 9))]);
    await _openMenu(tester);

    for (final label in [
      'Play all',
      'Play next',
      'Add to queue',
      'Create playlist from this day',
    ]) {
      expect(_enabled(tester, label), isFalse, reason: label);
    }
    expect(_enabled(tester, "Remove this day's listens"), isTrue);
  });

  historyTestWidgets('the pinned bar opens the same menu', (tester) async {
    await openHistory(
      tester,
      h,
      tracks: [for (var i = 0; i < 12; i++) song('S$i')],
      plays: [for (var i = 0; i < 12; i++) ('S$i', _at(23, i))],
    );
    await scrollTimelineTo(tester, lineExtentOf(tester) * 5);

    await tester.tap(
      find.descendant(
        of: find.byKey(historyStickyHeaderKey),
        matching: _dayMenu,
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'Play all');

    expect(_queue(h), [for (var i = 11; i >= 0; i--) '/m/S$i.flac']);
  });

  historyTestWidgets('removing the only day of an older year falls back to the '
      'newest year; Undo brings the year back at the top of the list', (
    tester,
  ) async {
    await openHistory(
      tester,
      h,
      tracks: [song('A'), song('B')],
      plays: [('A', _at(23, 9)), ('B', _at(31, 9, 12, 2025))],
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
    await settleHistory(tester);
    expect(find.text('B'), findsOneWidget);

    await _openMenu(tester);
    await _choose(tester, "Remove this day's listens");
    await settleHistory(tester);
    // The year has no plays: the page falls back to the newest year.
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await settleHistory(tester);
    // The scroll position resets; the restored year is a chip again.
    expect(find.widgetWithText(ChoiceChip, '2025'), findsOneWidget);
    expect(timelineOffset(tester), 0);
  });

  for (final scale in [1.0, 2.0]) {
    historyTestWidgets('rows and bars fit their lines at text scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await open(tester);

      expect(tester.takeException(), isNull);
      expect(listText(_day23), findsOneWidget);
      final line = lineExtentOf(tester);
      expect(line, greaterThanOrEqualTo(80));
      for (final tile in tester.widgetList(find.byType(HistoryPlayRowTile))) {
        expect(tester.getSize(find.byWidget(tile)).height, line);
      }
      expect(
        tester.getSize(find.byType(HistoryDayBar).first).height,
        barHeightOf(tester),
      );
    });
  }
}
