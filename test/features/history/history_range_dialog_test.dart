import 'dart:ui' show Tristate;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/history/history_calendar_style.dart';
import 'package:kanaru/features/history/history_range_dialog.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'history_test_harness.dart' show historyTestWidgets;

final _today = DateTime(2026, 10, 23);
final _bounds = (first: DateTime(2026, 9, 10), last: _today);

Finder _day(int month, int day, {int year = 2026}) =>
    find.byKey(historyDayCellKey(DateTime(year, month, day)));

HistoryDayCell _cell(WidgetTester tester, int month, int day) =>
    tester.widget<HistoryDayCell>(
      find.ancestor(
        of: _day(month, day),
        matching: find.byType(HistoryDayCell),
      ),
    );

class _Opened {
  _Opened(this.db);
  final LibraryDatabase db;

  /// What the dialog returned; one entry per time it closed.
  final results = <HistoryDayRange?>[];
}

/// Opens the dialog from a button over a database holding plays at [plays].
Future<_Opened> _open(
  WidgetTester tester, {
  List<DateTime> plays = const [],
  HistoryDayRange? initial,
  Locale locale = const Locale('en'),
}) async {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.runAsync(() async {
    for (final at in plays) {
      await db
          .into(db.plays)
          .insert(
            PlaysCompanion.insert(
              path: '/m/a.flac',
              playedAt: at.millisecondsSinceEpoch,
              listenedMs: const Value(60000),
            ),
          );
    }
  });
  final opened = _Opened(db);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => opened.results.add(
              await showHistoryRangeDialog(
                context,
                bounds: _bounds,
                today: _today,
                initial: initial,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _tapDay(WidgetTester tester, int month, int day) async {
  await tester.tap(_day(month, day));
  await tester.pumpAndSettle();
}

Future<void> _page(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  historyTestWidgets('opens on today\'s month with one dialog, six rows', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Pick the start date'), findsOneWidget);
    expect(find.text('Start date – End date'), findsOneWidget);
    // Six weeks: Sep 27 to Nov 7 are all in the grid.
    expect(_day(9, 27), findsOneWidget);
    expect(_day(11, 7), findsOneWidget);
    expect(_day(11, 8), findsNothing);
    expect(tester.takeException(), isNull);
  });

  historyTestWidgets('days after today and before the first play are off', (
    tester,
  ) async {
    await _open(tester);

    expect(_cell(tester, 10, 24).isDisabled, isTrue);
    expect(_cell(tester, 10, 23).isDisabled, isFalse);
    expect(_cell(tester, 9, 27).isDisabled, isFalse);
    await _tapDay(tester, 10, 24);
    expect(find.text('Pick the start date'), findsOneWidget);
    await _tapDay(tester, 10, 23);
    expect(find.text('Pick the end date'), findsOneWidget);

    await _page(tester, 'Previous month');
    expect(_cell(tester, 9, 9).isDisabled, isTrue);
    expect(_cell(tester, 9, 10).isDisabled, isFalse);
    await _tapDay(tester, 9, 9);
    // The tap on the disabled day changed nothing.
    expect(find.text('Oct 23, 2026 – End date'), findsOneWidget);
    expect(find.text('Pick the end date'), findsOneWidget);
  });

  historyTestWidgets('dots are on days with plays, by local day', (
    tester,
  ) async {
    await _open(
      tester,
      plays: [
        DateTime(2026, 10, 5, 14),
        DateTime(2026, 10, 5, 2),
        // Edges of a local day: the last minute of Sep 30 and the first of Oct 1.
        DateTime(2026, 9, 30, 23, 59),
        DateTime(2026, 10, 1),
      ],
    );

    final dotted = [
      for (var d = 1; d <= 23; d++)
        if (_cell(tester, 10, d).hasPlays) d,
    ];
    expect(dotted, [1, 5]);
    // Sep 30 shows in the October grid as a faded day, with its own dot.
    expect(_cell(tester, 9, 30).hasPlays, isTrue);
    expect(_cell(tester, 9, 29).hasPlays, isFalse);
  });

  historyTestWidgets('dots follow the month in view', (tester) async {
    await _open(tester, plays: [DateTime(2026, 9, 15, 9)]);

    expect(_cell(tester, 10, 5).hasPlays, isFalse);
    await _page(tester, 'Previous month');
    expect(find.text('September 2026'), findsOneWidget);
    expect(_cell(tester, 9, 15).hasPlays, isTrue);
    expect(_cell(tester, 9, 14).hasPlays, isFalse);
  });

  historyTestWidgets('start, end, an earlier day restarts, a later one ends', (
    tester,
  ) async {
    await _open(tester);

    await _tapDay(tester, 10, 10);
    expect(find.text('Oct 10, 2026 – End date'), findsOneWidget);
    await _tapDay(tester, 10, 14);
    expect(find.text('Oct 10 – Oct 14, 2026'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(_cell(tester, 10, 10).isEdge, isTrue);
    expect(_cell(tester, 10, 14).isEdge, isTrue);
    expect(_cell(tester, 10, 12).isEdge, isFalse);

    // A third tap starts over.
    await _tapDay(tester, 10, 6);
    expect(find.text('Oct 6, 2026 – End date'), findsOneWidget);
    // Before the start: the start moves and there is still no end.
    await _tapDay(tester, 10, 3);
    expect(find.text('Oct 3, 2026 – End date'), findsOneWidget);
    await _tapDay(tester, 10, 3);
    expect(find.text('Oct 3, 2026'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
  });

  historyTestWidgets('Save is off until both days are picked', (tester) async {
    final opened = await _open(tester);

    TextButton save() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
    expect(save().onPressed, isNull);
    await _tapDay(tester, 10, 10);
    expect(save().onPressed, isNull);
    await _tapDay(tester, 10, 12);
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(opened.results, [
      (start: DateTime(2026, 10, 10), end: DateTime(2026, 10, 12)),
    ]);
    expect(find.byType(Dialog), findsNothing);
  });

  historyTestWidgets('the selection survives paging to another month', (
    tester,
  ) async {
    final opened = await _open(tester);

    // Sep 28 shows faded in the October grid; tapping it selects it and pages.
    await _tapDay(tester, 9, 28);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Sep 28, 2026 – End date'), findsOneWidget);
    await _page(tester, 'Next month');
    expect(find.text('October 2026'), findsOneWidget);
    expect(_cell(tester, 9, 28).isEdge, isTrue);
    await _tapDay(tester, 10, 3);
    expect(find.text('Sep 28 – Oct 3, 2026'), findsOneWidget);
    expect(find.text('6 days'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened.results, [
      (start: DateTime(2026, 9, 28), end: DateTime(2026, 10, 3)),
    ]);
  });

  historyTestWidgets('the arrows stop at the first play and at today', (
    tester,
  ) async {
    await _open(tester);

    IconButton button(String tooltip) => tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(button('Next month').onPressed, isNull);
    expect(button('Previous month').onPressed, isNotNull);
    await _page(tester, 'Previous month');
    expect(button('Previous month').onPressed, isNull);
    expect(button('Next month').onPressed, isNotNull);
  });

  historyTestWidgets('Cancel and Esc keep nothing', (tester) async {
    final opened = await _open(tester);

    await _tapDay(tester, 10, 10);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened.results, [null]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(opened.results, [null, null]);
  });

  historyTestWidgets('Enter on Cancel cancels, on an arrow pages', (
    tester,
  ) async {
    final opened = await _open(tester);
    await _tapDay(tester, 10, 10);
    await _tapDay(tester, 10, 12);

    // The focus node closest to the button's content is the button's own.
    Focus.of(tester.element(find.byIcon(AppIcons.chevronLeft))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(opened.results, isEmpty);

    Focus.of(tester.element(find.text('Cancel'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(opened.results, [null]);
  });

  historyTestWidgets('numpad Enter saves when no button has the focus', (
    tester,
  ) async {
    final opened = await _open(tester);
    await _tapDay(tester, 10, 10);
    await _tapDay(tester, 10, 12);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(opened.results, [
      (start: DateTime(2026, 10, 10), end: DateTime(2026, 10, 12)),
    ]);
  });

  historyTestWidgets('rapid paging does not throw and keeps the dots right', (
    tester,
  ) async {
    await _open(
      tester,
      plays: [DateTime(2026, 9, 15, 9), DateTime(2026, 10, 5, 9)],
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.tap(find.byTooltip('Previous month'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('September 2026'), findsOneWidget);
    expect(_cell(tester, 9, 15).hasPlays, isTrue);
    expect(_cell(tester, 9, 14).hasPlays, isFalse);
    // Oct 5 is in the September grid's last row as a faded day.
    expect(_cell(tester, 10, 5).hasPlays, isTrue);
  });

  historyTestWidgets('a day reads as a button with state and a listens cue', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, plays: [DateTime(2026, 10, 5, 9)]);
    await _tapDay(tester, 10, 10);

    SemanticsData of(int month, int day) =>
        tester.getSemantics(_day(month, day)).getSemanticsData();

    final played = of(10, 5);
    expect(played.label, contains('Monday, October 5, 2026'));
    expect(played.label, contains('Has listens'));
    expect(played.flagsCollection.isButton, isTrue);
    expect(played.flagsCollection.isEnabled, Tristate.isTrue);
    expect(played.flagsCollection.isSelected, Tristate.isFalse);

    final plain = of(10, 6);
    expect(plain.label, isNot(contains('Has listens')));

    final picked = of(10, 10);
    expect(picked.flagsCollection.isSelected, Tristate.isTrue);

    final off = of(10, 24);
    expect(off.flagsCollection.isButton, isTrue);
    expect(off.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  historyTestWidgets('opens with the initial range on its end month', (
    tester,
  ) async {
    await _open(
      tester,
      initial: (start: DateTime(2026, 9, 12), end: DateTime(2026, 9, 20)),
    );

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Sep 12 – Sep 20, 2026'), findsOneWidget);
    expect(find.text('9 days'), findsOneWidget);
  });

  historyTestWidgets('English weeks start on Sunday', (tester) async {
    await _open(tester);

    // October 2026 starts on a Thursday; the grid begins on Sep 27.
    expect(_day(9, 27), findsOneWidget);
    expect(
      tester.getTopLeft(_day(9, 27)).dx,
      tester.getTopLeft(_day(10, 4)).dx,
    );
  });

  historyTestWidgets('Vietnamese weeks start on Monday, with its texts', (
    tester,
  ) async {
    await _open(tester, locale: const Locale('vi'));

    expect(_day(9, 27), findsNothing);
    expect(
      tester.getTopLeft(_day(9, 28)).dx,
      tester.getTopLeft(_day(10, 5)).dx,
    );
    expect(find.text('Chọn ngày bắt đầu'), findsOneWidget);
    expect(find.text('Ngày bắt đầu – Ngày kết thúc'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
  });
}
