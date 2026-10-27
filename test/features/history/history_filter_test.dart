import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_filter_results.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import 'history_test_harness.dart';

DateTime _at(int day, [int hour = 9, int month = 10, int year = 2026]) =>
    DateTime(year, month, day, hour);

final _tracks = [
  song('Lạ Lùng'),
  song('Lal Two'),
  song('Other'),
  song('Filler'),
];

/// The plays the filter lists, top to bottom.
List<DateTime> _shownAt(WidgetTester tester) => [
  for (final t in tester.widgetList<HistoryPlayRowTile>(
    find.descendant(
      of: find.byType(HistoryFilterResults),
      matching: find.byType(HistoryPlayRowTile),
    ),
  ))
    DateTime.fromMillisecondsSinceEpoch(t.row.playedAt),
];

Finder get _box => find.descendant(
  of: find.byType(InPageSearchBox),
  matching: find.byType(TextField),
);

Future<void> _filterBy(WidgetTester tester, String text) async {
  if (find.byType(InPageSearchBox).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(_box, text);
  await tester.pump(const Duration(milliseconds: 150));
  await settleHistory(tester);
}

void main() {
  late LibraryHarness h;
  late GatedQueryInterceptor gate;

  setUp(() {
    gate = GatedQueryInterceptor();
    h = historyHarness(interceptor: gate);
  });

  List<String> queued() => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.uri,
  ];

  Future<void> open(WidgetTester tester, List<SeedPlay> plays) =>
      openHistory(tester, h, tracks: _tracks, plays: plays);

  group('filtering the year', () {
    historyTestWidgets('lists the matching plays of the year, newest first', (
      tester,
    ) async {
      await open(tester, [
        ('Lạ Lùng', _at(20)),
        ('Other', _at(21)),
        ('Lạ Lùng', _at(22)),
        ('Lạ Lùng', _at(23, 8)),
        ('Lạ Lùng', _at(30, 9, 12, 2025)),
      ]);

      await _filterBy(tester, 'lung');

      expect(_shownAt(tester), [_at(23, 8), _at(22), _at(20)]);
      // The day bars are gone: one flat list.
      expect(find.byType(HistoryTimelineView), findsNothing);
      expect(find.text('Other'), findsNothing);
    });

    historyTestWidgets('matches the accent-free words of every term', (
      tester,
    ) async {
      await open(tester, [('Lạ Lùng', _at(20)), ('Lal Two', _at(21))]);

      await _filterBy(tester, 'la lung');

      expect(_shownAt(tester), [_at(20)]);
    });

    historyTestWidgets('Ctrl+F opens the box', (tester) async {
      await open(tester, [('Lal Two', _at(20))]);
      expect(find.byType(InPageSearchBox), findsNothing);

      expect(InPageFilterRegistry.instance.openTop(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(InPageSearchBox), findsOneWidget);
    });

    historyTestWidgets('says so when no play matches', (tester) async {
      await open(tester, [('Lal Two', _at(20))]);

      await _filterBy(tester, 'zzz');

      expect(find.text('No songs match “zzz”'), findsOneWidget);
      expect(find.byType(HistoryPlayRowTile), findsNothing);
    });

    historyTestWidgets('the calendar waits while the filter lists plays', (
      tester,
    ) async {
      await open(tester, [('Lal Two', _at(20))]);
      Finder button() => find.byTooltip('Jump to a day');
      expect(button(), findsOneWidget);
      final enabled = tester.widget<IconButton>(
        find.ancestor(of: button(), matching: find.byType(IconButton)).first,
      );
      expect(enabled.onPressed, isNotNull);

      await _filterBy(tester, 'lal');

      final disabled = tester.widget<IconButton>(
        find.ancestor(of: button(), matching: find.byType(IconButton)).first,
      );
      expect(disabled.onPressed, isNull);
    });

    historyTestWidgets('another year chip filters that year with the terms', (
      tester,
    ) async {
      await open(tester, [
        ('Lal Two', _at(20)),
        ('Lal Two', _at(30, 9, 12, 2025)),
        ('Lạ Lùng', _at(1, 9, 3, 2025)),
      ]);
      await _filterBy(tester, 'lal');
      expect(_shownAt(tester), [_at(20)]);

      await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
      await settleHistory(tester);

      expect(_shownAt(tester), [_at(30, 9, 12, 2025)]);
      expect(tester.widget<TextField>(_box).controller!.text, 'lal');
    });

    historyTestWidgets('a year change never leaves the old year\'s rows', (
      tester,
    ) async {
      await open(tester, [
        ('Lal Two', _at(20)),
        ('Lal Two', _at(30, 9, 12, 2025)),
      ]);
      await _filterBy(tester, 'lal');
      expect(_shownAt(tester), [_at(20)]);

      // Hold the 2025 read: until it ends, 2026's row must not be on show.
      final release = gate.holdNext('track_search');
      await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_shownAt(tester), isEmpty);

      release();
      await settleHistory(tester);
      expect(_shownAt(tester), [_at(30, 9, 12, 2025)]);
    });

    historyTestWidgets('a failed read shows the load-failed state', (
      tester,
    ) async {
      await open(tester, [('Lal Two', _at(20)), ('Lạ Lùng', _at(21))]);
      await _filterBy(tester, 'lal');
      expect(_shownAt(tester), [_at(20)]);

      gate.failNext('track_search');
      await _filterBy(tester, 'la');

      expect(
        find.text("Couldn't read the history. See the log for details."),
        findsOneWidget,
      );
      expect(find.byType(HistoryPlayRowTile), findsNothing);
    });
  });

  group('actions on the matches', () {
    historyTestWidgets('a tap queues the matched songs once, from the tapped', (
      tester,
    ) async {
      await open(tester, [
        ('Lal Two', _at(20)),
        ('Lạ Lùng', _at(21)),
        ('Lal Two', _at(22)),
        ('Other', _at(23)),
      ]);
      await _filterBy(tester, 'la');
      // Shown as Lal Two (22nd), Lạ Lùng (21st), Lal Two (20th).
      expect(_shownAt(tester), [_at(22), _at(21), _at(20)]);

      await tester.tap(find.text('Lạ Lùng'));
      await tester.pump();

      expect(queued(), ['/m/Lal Two.flac', '/m/Lạ Lùng.flac']);
      expect(
        h.container.read(playerServiceProvider).queue.current?.uri,
        '/m/Lạ Lùng.flac',
      );
    });

    historyTestWidgets('the row menu removes a play and the list follows', (
      tester,
    ) async {
      await open(tester, [('Lal Two', _at(20)), ('Lal Two', _at(21))]);
      await _filterBy(tester, 'lal');

      await tester.longPress(find.byType(HistoryPlayRowTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Add to queue'), findsOneWidget);
      await tester.tap(find.text('Remove from history'));
      await settleHistory(tester);

      expect(_shownAt(tester), [_at(20)]);
    });

    historyTestWidgets('over the limit, the last line says it was cut', (
      tester,
    ) async {
      await open(tester, [('Other', _at(1))]);
      await tester.runAsync(() async {
        final start = _at(2).millisecondsSinceEpoch;
        await h.db.batch(
          (b) => b.insertAll(h.db.plays, [
            for (var i = 0; i < 1001; i++)
              PlaysCompanion.insert(
                path: '/m/Lal Two.flac',
                playedAt: start + i * 1000,
                listenedMs: const Value(60000),
              ),
          ]),
        );
      });
      await settleHistory(tester);

      await _filterBy(tester, 'lal');
      final list = find.descendant(
        of: find.byType(HistoryFilterResults),
        matching: find.byType(Scrollable),
      );
      tester
          .state<ScrollableState>(list.first)
          .position
          .jumpTo(
            tester.state<ScrollableState>(list.first).position.maxScrollExtent,
          );
      await tester.pump();

      expect(find.text('Showing first 1000'), findsOneWidget);
    });
  });

  group('closing the filter', () {
    historyTestWidgets(
      'a play removed while filtering is gone from the timeline',
      (tester) async {
        await open(tester, [
          ('Lal Two', _at(20)),
          ('Lal Two', _at(21)),
          ('Other', _at(22)),
        ]);
        expect(listText('Lal Two'), findsNWidgets(2));
        await _filterBy(tester, 'lal');

        await tester.longPress(find.byType(HistoryPlayRowTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove from history'));
        await settleHistory(tester);
        expect(_shownAt(tester), [_at(20)]);

        await tester.tap(_box);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleHistory(tester);

        expect(find.byType(HistoryFilterResults), findsNothing);
        expect(listText('Lal Two'), findsOneWidget);
        expect(listText('Other'), findsOneWidget);
      },
    );

    historyTestWidgets('Esc brings the timeline back at the same offset', (
      tester,
    ) async {
      await open(tester, [
        for (var d = 1; d <= 22; d++) ('Filler', _at(d)),
        ('Lal Two', _at(23)),
      ]);
      await scrollTimelineTo(tester, 600);
      final before = timelineOffset(tester);
      expect(before, closeTo(600, 0.5));

      await _filterBy(tester, 'lal');
      expect(find.byType(HistoryTimelineView), findsNothing);
      expect(_shownAt(tester), [_at(23)]);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleHistory(tester);

      expect(find.byType(HistoryFilterResults), findsNothing);
      expect(find.byType(HistoryTimelineView), findsOneWidget);
      expect(timelineOffset(tester), before);
    });
  });
}
