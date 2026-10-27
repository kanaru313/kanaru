import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_list.dart';
import 'package:kanaru/features/history/most_played_row_tile.dart';
import 'package:kanaru/features/history/most_played_side_pane.dart';
import 'package:kanaru/shared/widgets/detail_page/tracks_toolbar.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import 'history_test_harness.dart';

DateTime _at(int month, int day, [int hour = 9]) =>
    DateTime(2026, month, day, hour);

/// In the last 30 days: A and B 3 plays each (B's last one earlier), C one,
/// the Ghost (not in the library) two. D, 5 plays, is older.
final _plays = <SeedPlay>[
  for (final d in [20, 21, 22]) ('A', _at(10, d)),
  for (final d in [10, 11, 12]) ('B', _at(10, d)),
  ('C', _at(10, 22, 10)),
  ('Ghost', _at(10, 15)),
  ('Ghost', _at(10, 15, 10)),
  for (var i = 0; i < 5; i++) ('D', _at(2, 1, 8 + i)),
];

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  Future<void> open(WidgetTester tester) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('C'), song('D')],
    plays: _plays,
    page: mostPlayedPath,
  );

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  Finder inPane(Finder finder) =>
      find.descendant(of: find.byType(MostPlayedSidePane), matching: finder);

  group('pane', () {
    historyTestWidgets('names the range and counts the whole window', (
      tester,
    ) async {
      await open(tester);

      expect(inPane(find.text('Most played')), findsOneWidget);
      expect(
        inPane(find.text('30 days · Sep 24 – Oct 23, 2026')),
        findsOneWidget,
      );
      // Ghost counts: it was played, even if the file is gone.
      expect(inPane(find.text('4 songs · 9 listens')), findsOneWidget);
    });

    historyTestWidgets('totals follow the range, all time is by itself', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '7 days'));
      await settleHistory(tester);
      expect(inPane(find.text('2 songs · 4 listens')), findsOneWidget);

      final all = find.widgetWithText(ChoiceChip, 'All time');
      await tester.ensureVisible(all);
      await tester.pump();
      await tester.tap(all);
      await settleHistory(tester);
      expect(inPane(find.text('All time')), findsOneWidget);
      expect(inPane(find.text('5 songs · 14 listens')), findsOneWidget);
    });

    historyTestWidgets('Today and Custom name their days', (tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
      await settleHistory(tester);
      expect(inPane(find.text('Today · Oct 23, 2026')), findsOneWidget);

      final custom = find.widgetWithText(ChoiceChip, 'Custom');
      await tester.ensureVisible(custom);
      await tester.pump();
      await tester.tap(custom);
      await settleHistory(tester);
      final dialog = find.byType(Dialog);
      await tester.tap(find.descendant(of: dialog, matching: find.text('10')));
      await tester.pump();
      await tester.tap(find.descendant(of: dialog, matching: find.text('12')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleHistory(tester);
      expect(
        inPane(find.text('Custom · Oct 10 – Oct 12, 2026')),
        findsOneWidget,
      );
      expect(inPane(find.text('1 song · 3 listens')), findsOneWidget);
    });

    historyTestWidgets('totals of the old range are gone while the new ones '
        'are read', (tester) async {
      final gate = GatedQueryInterceptor();
      h = historyHarness(interceptor: gate);
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B'), song('C'), song('D')],
        plays: _plays,
        gate: gate,
        page: mostPlayedPath,
      );
      expect(inPane(find.text('4 songs · 9 listens')), findsOneWidget);

      final release = gate.holdNext(historyRangeSummarySql);
      await tester.tap(find.widgetWithText(ChoiceChip, '7 days'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(inPane(find.textContaining('7 days · ')), findsOneWidget);
      expect(inPane(find.textContaining(' listens')), findsNothing);

      release();
      await settleHistory(tester);
      expect(inPane(find.text('2 songs · 4 listens')), findsOneWidget);
    });

    historyTestWidgets('totals are not cut with the list', (tester) async {
      await openHistory(
        tester,
        h,
        plays: [for (var i = 0; i < 501; i++) ('g$i', _at(10, 22, i % 24))],
        page: mostPlayedPath,
      );

      expect(inPane(find.text('501 songs · 501 listens')), findsOneWidget);
    });

    historyTestWidgets('Shuffle queues the playable songs', (tester) async {
      await open(tester);

      await tester.tap(inPane(find.byTooltip('Shuffle')));
      await tester.pump();

      expect(_queue(h).toSet(), {'/m/A.flac', '/m/B.flac', '/m/C.flac'});
    });

    historyTestWidgets('the more menu is vertical and queues the songs', (
      tester,
    ) async {
      await open(tester);

      expect(inPane(find.byIcon(Icons.more_vert)), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Create playlist'), findsOneWidget);
      expect(find.text('Play next'), findsOneWidget);

      await tester.tap(find.text('Add to queue'));
      await settleHistory(tester);
      expect(_queue(h), ['/m/B.flac', '/m/A.flac', '/m/C.flac']);
    });

    historyTestWidgets('a narrow window shows the header above the list', (
      tester,
    ) async {
      await open(tester);
      await resize(tester, const Size(800, 800));

      expect(find.byType(MostPlayedSidePane), findsNothing);
      expect(find.byType(MostPlayedHeader), findsOneWidget);
      expect(find.text('4 songs · 9 listens'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(MostPlayedHeader)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TracksToolbar)).dy),
      );
    });
  });

  group('rows', () {
    historyTestWidgets('are library song rows numbered by rank', (
      tester,
    ) async {
      await open(tester);

      // B, A, Ghost (no song row), C.
      expect(find.byType(SongTile), findsNWidgets(3));
      for (final (i, rank) in ['1', '2', '3', '4'].indexed) {
        expect(
          find.descendant(
            of: find.byType(MostPlayedRowTile).at(i),
            matching: find.text(rank),
          ),
          findsOneWidget,
        );
      }
    });

    historyTestWidgets('the top three ranks use the accent colour', (
      tester,
    ) async {
      await open(tester);
      final colors = Theme.of(tester.element(find.byType(MostPlayedList)))
          .colorScheme;

      Color? rankColor(int i, String rank) => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(MostPlayedRowTile).at(i),
              matching: find.text(rank),
            ),
          )
          .style
          ?.color;
      expect(rankColor(0, '1'), colors.primary);
      expect(rankColor(2, '3'), colors.primary);
      expect(rankColor(3, '4'), colors.onSurfaceVariant);
    });

    historyTestWidgets('the listens badge sits above the duration', (
      tester,
    ) async {
      await open(tester);
      final row = find.byType(MostPlayedRowTile).first;

      final badge = find.descendant(of: row, matching: find.text('3 listens'));
      final duration = find.descendant(of: row, matching: find.text('0:01'));
      expect(badge, findsOneWidget);
      expect(
        tester.getBottomLeft(badge).dy,
        lessThanOrEqualTo(tester.getTopLeft(duration).dy),
      );
      expect(tester.takeException(), isNull);
    });

    historyTestWidgets('the badge fits the row at a large text scale', (
      tester,
    ) async {
      await open(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(find.text('3 listens'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('filter', () {
    Future<void> filterBy(WidgetTester tester, String text) async {
      if (find.byType(InPageSearchBox).evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Filter in this page'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.descendant(
          of: find.byType(InPageSearchBox),
          matching: find.byType(TextField),
        ),
        text,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await settleHistory(tester);
    }

    historyTestWidgets('keeps the ranks and the rank order', (tester) async {
      await open(tester);

      await filterBy(tester, 'c');
      expect(find.byType(MostPlayedRowTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MostPlayedRowTile),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );

      // A song gone from the library is found by its file name.
      await filterBy(tester, 'ghost');
      expect(find.byType(MostPlayedRowTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MostPlayedRowTile),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    historyTestWidgets('Ctrl+F opens the box', (tester) async {
      await open(tester);
      expect(find.byType(InPageSearchBox), findsNothing);

      expect(InPageFilterRegistry.instance.openTop(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(InPageSearchBox), findsOneWidget);
    });

    historyTestWidgets('the toolbar counts the rows shown', (tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byType(TracksToolbar),
          matching: find.text('4 songs'),
        ),
        findsOneWidget,
      );

      await filterBy(tester, 'c');

      expect(
        find.descendant(
          of: find.byType(TracksToolbar),
          matching: find.text('1 song'),
        ),
        findsOneWidget,
      );
    });

    historyTestWidgets('says so when no song matches', (tester) async {
      await open(tester);

      await filterBy(tester, 'zzz');

      expect(find.byType(MostPlayedRowTile), findsNothing);
      expect(find.text('No songs match “zzz”'), findsOneWidget);
    });
  });
}
