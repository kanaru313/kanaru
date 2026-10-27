import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/history_calendar_dialog.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

HistoryDayCount _day(int year, int month, int day, [int count = 1]) =>
    HistoryDayCount(
      dayStart: DateTime(year, month, day).millisecondsSinceEpoch,
      count: count,
      tracks: 1,
    );

Finder _cell(int day) => find.byKey(ValueKey('history-calendar-day-$day'));

bool _enabled(WidgetTester tester, int day) =>
    tester.widget<InkResponse>(_cell(day)).onTap != null;

/// Opens the calendar from a button and returns what it picked.
Future<void> _open(
  WidgetTester tester, {
  required int year,
  required List<HistoryDayCount> counts,
  required List<DateTime?> picked,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked.add(
            await showHistoryCalendar(context, year: year, counts: counts),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the month of the latest play, others are disabled', (
    tester,
  ) async {
    final picked = <DateTime?>[];
    await _open(
      tester,
      year: 2026,
      counts: [_day(2026, 10, 23), _day(2026, 10, 10, 3), _day(2026, 8, 1)],
      picked: picked,
    );

    expect(find.text('October 2026'), findsOneWidget);
    expect(_enabled(tester, 23), isTrue);
    expect(_enabled(tester, 10), isTrue);
    expect(_enabled(tester, 11), isFalse);
    expect(_enabled(tester, 1), isFalse);
    // October has 31 days, no more.
    expect(_cell(31), findsOneWidget);
    expect(_cell(32), findsNothing);
  });

  testWidgets('a day is read out with its date and how many plays', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(
      tester,
      year: 2026,
      counts: [_day(2026, 10, 10, 3)],
      picked: [],
    );

    expect(
      find.bySemanticsLabel('Saturday, October 10, 2026, 3 listens'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('days sit under their weekday, the week starting on Sunday', (
    tester,
  ) async {
    await _open(tester, year: 2026, counts: [_day(2026, 10, 23)], picked: []);

    double dx(int day) => tester.getCenter(_cell(day)).dx;
    double dy(int day) => tester.getCenter(_cell(day)).dy;
    // 2026-10-01 is a Thursday; the 4th, 11th, 18th and 25th are Sundays.
    expect(dx(1), dx(8));
    expect(dx(4), dx(11));
    expect(dx(4), lessThan(dx(1)));
    expect(dy(4), greaterThan(dy(1)));
    expect(dy(1), dy(3));
  });

  testWidgets('February of a leap year has 29 days', (tester) async {
    await _open(tester, year: 2024, counts: [_day(2024, 2, 29)], picked: []);

    expect(find.text('February 2024'), findsOneWidget);
    expect(_enabled(tester, 29), isTrue);
    expect(_cell(30), findsNothing);
  });

  testWidgets('months step within the year only', (tester) async {
    await _open(
      tester,
      year: 2026,
      counts: [_day(2026, 12, 20), _day(2026, 1, 5)],
      picked: [],
    );

    IconButton button(String tooltip) => tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(find.text('December 2026'), findsOneWidget);
    expect(button('Next month').onPressed, isNull);
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
    }
    expect(find.text('January 2026'), findsOneWidget);
    expect(button('Previous month').onPressed, isNull);
    expect(_enabled(tester, 5), isTrue);
  });

  testWidgets('picking a day with plays closes the dialog with it', (
    tester,
  ) async {
    final picked = <DateTime?>[];
    await _open(
      tester,
      year: 2026,
      counts: [_day(2026, 10, 23), _day(2026, 10, 10)],
      picked: picked,
    );

    await tester.tap(_cell(11), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.byType(HistoryCalendar), findsOneWidget);

    await tester.tap(_cell(10));
    await tester.pumpAndSettle();

    expect(picked, [DateTime(2026, 10, 10)]);
    expect(find.byType(HistoryCalendar), findsNothing);
  });

  testWidgets('closing without a pick returns nothing', (tester) async {
    final picked = <DateTime?>[];
    await _open(
      tester,
      year: 2026,
      counts: [_day(2026, 10, 23)],
      picked: picked,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(picked, [null]);
  });
}
