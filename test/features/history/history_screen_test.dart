import 'package:drift/drift.dart' show ComparableExpr;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/history/history_clock.dart';
import 'package:kanaru/features/history/history_screen.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import 'history_test_harness.dart';

DateTime _at(int year, int month, int day, [int hour = 9]) =>
    DateTime(year, month, day, hour);

Finder _chip(int year) => find.widgetWithText(ChoiceChip, '$year');

void main() {
  group('states', () {
    testWidgets('without a library it says history is not available', (
      tester,
    ) async {
      final h = LibraryHarness(hasDatabase: false);
      await h.pump(tester);
      goTo(tester, h, '/history');
      await tester.pumpAndSettle();

      expect(find.text('History is not available'), findsOneWidget);
      expect(find.byTooltip('Jump to a day'), findsNothing);
    });

    testWidgets('with no plays it says songs will show up here', (
      tester,
    ) async {
      final h = historyHarness();
      await openHistory(tester, h);

      expect(find.text('Songs you play will show up here.'), findsOneWidget);
      expect(find.text('Recording listen history is turned off'), findsNothing);
      expect(find.byTooltip('Jump to a day'), findsNothing);
    });

    testWidgets('and recording turned off, it says that too', (tester) async {
      final h = historyHarness(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(recordListenHistory: false),
          ),
        ],
      );
      await openHistory(tester, h);

      expect(find.text('Songs you play will show up here.'), findsOneWidget);
      expect(
        find.text('Recording listen history is turned off'),
        findsOneWidget,
      );
    });

    testWidgets('a failed read says so, the log has no path', (tester) async {
      final gate = GatedQueryInterceptor();
      final h = historyHarness(interceptor: gate);
      final logs = <LogRecord>[];
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(logs.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = level;
      });
      await insertTracks(tester, h, [song('A')]);
      await seedPlays(tester, h, [('A', _at(2026, 10, 23))]);
      await h.pump(tester, hasRoots: true);
      gate.failNext('min(played_at)');
      goTo(tester, h, '/history');
      await settleHistory(tester);

      expect(
        find.text("Couldn't read the history. See the log for details."),
        findsOneWidget,
      );
      expect(logs.any((r) => r.message.contains('StateError')), isTrue);
      for (final r in logs) {
        expect(r.message, isNot(contains('/m/')));
      }
    });

    for (final (code, title, today, one, tip) in [
      ('en', 'History', 'Today', '1 listen', 'Listen number 1'),
      ('vi', 'Lịch sử', 'Hôm nay', '1 lượt nghe', 'Lượt nghe thứ 1'),
    ]) {
      testWidgets('speaks $code', (tester) async {
        final db = LibraryDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(() async {
          await db
              .into(db.plays)
              .insert(
                PlaysCompanion.insert(
                  path: '/m/a.flac',
                  playedAt: DateTime(2026, 10, 23, 9).millisecondsSinceEpoch,
                ),
              );
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryDatabaseProvider.overrideWithValue(db),
              historyNowProvider.overrideWithValue(() => historyTestNow),
            ],
            child: MaterialApp(
              locale: Locale(code),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: HistoryScreen()),
            ),
          ),
        );
        await settleHistory(tester);

        expect(find.text(title), findsOneWidget);
        expect(listText(today), findsOneWidget);
        expect(listText(one), findsOneWidget);
        expect(find.byTooltip(tip), findsOneWidget);
        // The song is not in the library: the file name stands in.
        expect(find.text('a.flac'), findsOneWidget);
      });
    }
  });

  group('years', () {
    final tracks = [song('A'), song('B'), song('C')];

    testWidgets('one year shows no chips', (tester) async {
      final h = historyHarness();
      await openHistory(
        tester,
        h,
        tracks: tracks,
        plays: [('A', _at(2026, 10, 23))],
      );

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('the newest year shows first; a chip picks another year', (
      tester,
    ) async {
      final h = historyHarness();
      await openHistory(
        tester,
        h,
        tracks: tracks,
        plays: [
          ('A', _at(2026, 10, 23)),
          ('B', _at(2025, 12, 31)),
          ('C', _at(2025, 6, 1)),
        ],
      );

      expect(_chip(2026), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_chip(2026)).selected, isTrue);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);

      await tester.tap(_chip(2025));
      await settleHistory(tester);

      expect(tester.widget<ChoiceChip>(_chip(2025)).selected, isTrue);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('Show 2025'), findsNothing);
    });

    testWidgets('the list ends with a row that shows the older year', (
      tester,
    ) async {
      final h = historyHarness();
      await openHistory(
        tester,
        h,
        tracks: tracks,
        plays: [('A', _at(2026, 10, 23)), ('B', _at(2025, 12, 31))],
      );

      await tester.tap(find.text('Show 2025'));
      await settleHistory(tester);

      expect(find.text('B'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_chip(2025)).selected, isTrue);
    });

    testWidgets('a year with no plays left falls back to the newest', (
      tester,
    ) async {
      final h = historyHarness();
      await openHistory(
        tester,
        h,
        tracks: tracks,
        plays: [('A', _at(2026, 10, 23)), ('B', _at(2025, 12, 31))],
      );
      await tester.tap(_chip(2025));
      await settleHistory(tester);
      expect(find.text('B'), findsOneWidget);

      await tester.runAsync(
        () =>
            (h.db.delete(h.db.plays)..where(
                  (p) => p.playedAt.isSmallerThanValue(
                    DateTime(2026).millisecondsSinceEpoch,
                  ),
                ))
                .go(),
      );
      await settleHistory(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });
  });

  group('calendar', () {
    // One play on each of these days, newest first: day k's header is line
    // 2k of the list.
    final days = [
      (10, 23),
      (10, 10),
      (9, 5),
      (8, 1),
      (7, 4),
      (6, 6),
      (5, 2),
      (4, 9),
      (3, 13),
      (2, 20),
      (1, 15),
    ];

    Future<LibraryHarness> openYear(WidgetTester tester) async {
      final h = historyHarness();
      await openHistory(
        tester,
        h,
        tracks: [for (var i = 0; i < days.length; i++) song('S$i')],
        plays: [
          for (final (i, (m, d)) in days.indexed) ('S$i', _at(2026, m, d)),
        ],
      );
      return h;
    }

    Future<void> openCalendar(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Jump to a day'));
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester, int months) async {
      for (var i = 0; i < months; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pump();
      }
    }

    testWidgets('a day in the middle of the year goes to the top', (
      tester,
    ) async {
      await openYear(tester);
      await openCalendar(tester);
      expect(find.text('October 2026'), findsOneWidget);

      // Aug 1 is day 3: line 6.
      await back(tester, 2);
      await tester.tap(find.byKey(const ValueKey('history-calendar-day-1')));
      await settleHistory(tester);

      expect(find.byType(Dialog), findsNothing);
      expect(
        timelineScrollable(tester).position.maxScrollExtent,
        greaterThan(6 * rowExtent),
      );
      expect(timelineOffset(tester), 6 * rowExtent);
      expect(stickyText('Saturday, August 1, 2026'), findsOneWidget);
    });

    testWidgets('a day near the end stops at the end of the list', (
      tester,
    ) async {
      await openYear(tester);
      await openCalendar(tester);

      // Jan 15 is day 10: line 20, further than the list can scroll.
      await back(tester, 9);
      await tester.tap(find.byKey(const ValueKey('history-calendar-day-15')));
      await settleHistory(tester);

      final position = timelineScrollable(tester).position;
      expect(20 * rowExtent, greaterThan(position.maxScrollExtent));
      expect(position.pixels, position.maxScrollExtent);
    });

    testWidgets('a day with no plays cannot be picked', (tester) async {
      await openYear(tester);
      await openCalendar(tester);

      await tester.tap(
        find.byKey(const ValueKey('history-calendar-day-24')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(timelineOffset(tester), 0);
    });
  });
}
