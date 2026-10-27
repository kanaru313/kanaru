import 'package:flutter_test/flutter_test.dart';

import 'dart:math';

import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_page_layout.dart';
import 'package:kanaru/features/history/history_side_pane.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/detail_page/tracks_toolbar.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import 'history_test_harness.dart';

DateTime _at(int year, int month, int day, [int hour = 9]) =>
    DateTime(year, month, day, hour);

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

Finder _chip(int year) => find.widgetWithText(ChoiceChip, '$year');

void main() {
  late LibraryHarness h;
  late GatedQueryInterceptor gate;

  setUp(() {
    gate = GatedQueryInterceptor();
    h = historyHarness(
      interceptor: gate,
      overrides: [
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(3)),
        ),
      ],
    );
  });

  /// 2026: A (Oct 10), B (Oct 12), A and a song gone from the library
  /// (Oct 20), Z (Oct 22). 2025: one play of Z.
  Future<void> open(WidgetTester tester) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('Z')],
    plays: [
      ('Z', _at(2025, 3, 1)),
      ('A', _at(2026, 10, 10)),
      ('B', _at(2026, 10, 12)),
      ('A', _at(2026, 10, 20, 8)),
      ('gone', _at(2026, 10, 20, 9)),
      ('Z', _at(2026, 10, 22)),
    ],
  );

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  historyTestWidgets('a wide window shows the side pane with the totals', (
    tester,
  ) async {
    await open(tester);

    // The harness window is wide; the narrow tests resize it themselves.
    expect(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      greaterThanOrEqualTo(1000),
    );
    expect(find.byType(HistorySidePane), findsOneWidget);
    expect(find.byType(HistoryHeader), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HistorySidePane),
        matching: find.text('History'),
      ),
      findsOneWidget,
    );
    expect(find.text('6 listens · since Mar 1, 2025'), findsOneWidget);
  });

  historyTestWidgets('a narrow window shows the header above the list', (
    tester,
  ) async {
    await open(tester);
    await resize(tester, const Size(800, 800));

    expect(find.byType(HistorySidePane), findsNothing);
    expect(find.byType(HistoryHeader), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(HistoryHeader)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(HistoryTimelineView)).dy),
    );
  });

  historyTestWidgets('a narrow header keeps the toolbar below it and plays', (
    tester,
  ) async {
    await open(tester);
    await resize(tester, const Size(800, 800));

    expect(
      tester.getTopLeft(find.byType(TracksToolbar)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(HistoryHeader)).dy),
    );
    expect(find.text('6 listens · since Mar 1, 2025'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(HistoryHeader),
        matching: find.byIcon(AppIcons.play),
      ),
    );
    await settleHistory(tester);
    expect(_queue(h), ['/m/Z.flac', '/m/A.flac', '/m/B.flac']);
  });

  test('the tint keys do not depend on the order of the covers', () {
    HistoryOverview of(List<String> keys) => HistoryOverview(
      plays: 1,
      tracks: 1,
      firstPlayedAt: null,
      coverKeys: keys,
    );

    expect(
      historyTintKeys(of(['b', 'c', 'a'])),
      historyTintKeys(of(['a', 'b', 'c'])),
    );
    expect(historyTintKeys(null), isEmpty);
  });

  historyTestWidgets('the toolbar totals follow the selected year', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('5 listens · 4 songs'), findsOneWidget);

    await tester.tap(_chip(2025));
    await settleHistory(tester);
    expect(find.text('1 listen · 1 song'), findsOneWidget);
    expect(find.text('5 listens · 4 songs'), findsNothing);
  });

  historyTestWidgets('the calendar button sits right of the filter and jumps', (
    tester,
  ) async {
    await open(tester);

    final filter = find.descendant(
      of: find.byType(TracksToolbar),
      matching: find.byIcon(AppIcons.search),
    );
    final calendar = find.byTooltip('Jump to a day');
    expect(filter, findsOneWidget);
    expect(
      tester.getTopLeft(calendar).dx,
      greaterThan(tester.getTopLeft(filter).dx),
    );

    await tester.tap(calendar);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });

  historyTestWidgets(
    'Play queues every played library song, last played first',
    (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await settleHistory(tester);

      // Last plays: Z Oct 22, A Oct 20, B Oct 12; the missing file is skipped.
      expect(_queue(h), ['/m/Z.flac', '/m/A.flac', '/m/B.flac']);
    },
  );

  historyTestWidgets('Shuffle queues the same songs', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Shuffle'));
    await settleHistory(tester);

    expect(_queue(h).toSet(), {'/m/Z.flac', '/m/A.flac', '/m/B.flac'});
    expect(_queue(h), hasLength(3));
    final queue = h.container.read(playerServiceProvider).queue;
    expect(queue.shuffled, isTrue);
    expect(
      [for (final t in queue.original) t.uri],
      ['/m/Z.flac', '/m/A.flac', '/m/B.flac'],
      reason: 'the played order is kept for when shuffle is turned off',
    );
  });

  historyTestWidgets(
    'a failed Shuffle read shows an error and queues nothing',
    (tester) async {
      await open(tester);
      gate.failNext('ORDER BY s.last_played_at DESC, s.path');
      await tester.tap(find.byTooltip('Shuffle'));
      await settleHistory(tester);

      expect(
        find.text('Something went wrong. See the log for details.'),
        findsOneWidget,
      );
      expect(_queue(h), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  historyTestWidgets('a failed totals read shows no listens count', (
    tester,
  ) async {
    gate.failNext('min(first_played_at)');
    await open(tester);

    expect(find.byType(HistorySidePane), findsOneWidget);
    expect(
      find.textContaining('listens'),
      findsOneWidget,
      reason: 'only the toolbar totals of the year',
    );
    expect(find.textContaining('0 listens'), findsNothing);
    expect(find.textContaining('since'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  historyTestWidgets('the toolbar keeps the old totals while a year loads', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('5 listens · 4 songs'), findsOneWidget);

    final release = gate.holdNext('count(DISTINCT path) AS tracks');
    await tester.tap(_chip(2025));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5 listens · 4 songs'), findsOneWidget);

    release();
    await settleHistory(tester);
    expect(find.text('1 listen · 1 song'), findsOneWidget);
  });

  historyTestWidgets('the queue menu adds the songs with Add to queue', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(HistorySidePane),
        matching: find.byType(PopupMenuButton<QueueAction>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await settleHistory(tester);

    expect(_queue(h), ['/m/Z.flac', '/m/A.flac', '/m/B.flac']);
  });
}
