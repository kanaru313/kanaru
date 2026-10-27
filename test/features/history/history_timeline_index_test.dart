import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/history_line_metrics.dart';
import 'package:kanaru/features/history/history_timeline_index.dart';

HistoryDayCount _day(int start, int count) =>
    HistoryDayCount(dayStart: start, count: count, tracks: 1);

void main() {
  test('no days is an empty list', () {
    final index = HistoryTimelineIndex(const []);
    expect(index.itemCount, 0);
    expect(index.firstIndexOfDay(5), -1);
  });

  test('no days but an older year is the offer alone', () {
    final index = HistoryTimelineIndex(const [], hasOlderYear: true);
    expect(index.itemCount, 1);
    expect(index.isFooter(0), isTrue);
    expect(index.itemAt(0).row, -1);
  });

  test('a day with one play is a header and a row', () {
    final index = HistoryTimelineIndex([_day(100, 1)]);
    expect(index.itemCount, 2);
    expect(index.itemAt(0), (day: 0, row: -1));
    expect(index.itemAt(1), (day: 0, row: 0));
    expect(index.isFooter(1), isFalse);
  });

  test('days are laid out newest first, each a header then its rows', () {
    final index = HistoryTimelineIndex([
      _day(300, 3),
      _day(200, 1),
      _day(100, 2),
    ]);
    expect(index.itemCount, 4 + 2 + 3);
    final lines = [for (var i = 0; i < index.itemCount; i++) index.itemAt(i)];
    expect(lines, [
      (day: 0, row: -1),
      (day: 0, row: 0),
      (day: 0, row: 1),
      (day: 0, row: 2),
      (day: 1, row: -1),
      (day: 1, row: 0),
      (day: 2, row: -1),
      (day: 2, row: 0),
      (day: 2, row: 1),
    ]);
    expect(
      [for (var i = 0; i < 9; i++) index.dayIndexAtItem(i)],
      [0, 0, 0, 0, 1, 1, 2, 2, 2],
    );
  });

  test('the older-year line comes after the last day', () {
    final index = HistoryTimelineIndex([
      _day(200, 1),
      _day(100, 1),
    ], hasOlderYear: true);
    expect(index.itemCount, 5);
    expect(index.isFooter(3), isFalse);
    expect(index.isFooter(4), isTrue);
    expect(index.dayIndexAtItem(4), 2);
    expect(index.itemAt(4), (day: 2, row: -1));
  });

  test('firstIndexOfDay finds a header, and misses days without plays', () {
    final index = HistoryTimelineIndex([
      _day(300, 3),
      _day(200, 1),
      _day(100, 2),
    ]);
    expect(index.firstIndexOfDay(300), 0);
    expect(index.firstIndexOfDay(200), 4);
    expect(index.firstIndexOfDay(100), 6);
    expect(index.firstIndexOfDay(250), -1);
    expect(index.firstIndexOfDay(400), -1);
    expect(index.firstIndexOfDay(50), -1);
  });

  test('a big list is searched, not scanned: every line maps back', () {
    final days = [for (var d = 1000; d > 0; d--) _day(d, d % 7 + 1)];
    final index = HistoryTimelineIndex(days);
    var line = 0;
    for (var d = 0; d < days.length; d++) {
      expect(index.firstIndexOfDay(days[d].dayStart), line);
      expect(index.itemAt(line), (day: d, row: -1));
      final last = line + days[d].count;
      expect(index.itemAt(last), (day: d, row: days[d].count - 1));
      line = last + 1;
    }
    expect(index.itemCount, line);
  });

  group('bar offsets', () {
    // Rows are 100 tall, header lines 70: a 40 bar with 20 above and 10
    // below it.
    const m = HistoryLineMetrics(line: 100, bar: 40, topGap: 20, bottomGap: 10);
    final index = HistoryTimelineIndex([
      _day(300, 3), // lines 0-3
      _day(200, 1), // lines 4-5
      _day(100, 2), // lines 6-8
    ]);

    test('header lines are told from song lines', () {
      expect(
        [for (var i = 0; i < 9; i++) index.isHeader(i)],
        [
          true, false, false, false, //
          true, false, //
          true, false, false,
        ],
      );
    });

    test('a header line starts after the shorter lines before it', () {
      expect(index.headerOffsetOfDay(0, m), 0);
      expect(index.headerOffsetOfDay(1, m), 70 + 300);
      expect(index.headerOffsetOfDay(2, m), 70 + 300 + 70 + 100);
    });

    test('the bar of a day starts below the gap of its header line', () {
      expect(index.barOffsetOfDay(0, m), 20);
      expect(index.barOffsetOfDay(1, m), 390);
      expect(index.barOffsetOfDay(2, m), 560);
    });

    test('dayIndexOfStart finds a day and misses others', () {
      expect(index.dayIndexOfStart(200), 1);
      expect(index.dayIndexOfStart(250), -1);
    });

    test('nothing is pinned while the first bar is still in the list', () {
      expect(index.stickyAt(0, m), isNull);
      expect(index.stickyAt(19.9, m), isNull);
    });

    test('inside a day its bar is pinned in place', () {
      expect(index.stickyAt(20, m), (day: 0, dy: 0.0));
      expect(index.stickyAt(300, m), (day: 0, dy: 0.0));
      expect(index.stickyAt(350, m), (day: 0, dy: 0.0));
    });

    test('the next bar pushes the pinned one up as it arrives', () {
      // Next bar at 390 reaches the pinned bar's bottom (offset + 40) at 350.
      expect(index.stickyAt(360, m), (day: 0, dy: -10.0));
      expect(index.stickyAt(389, m), (day: 0, dy: -39.0));
      expect(index.stickyAt(390, m), (day: 1, dy: 0.0));
    });

    test('the last day is never pushed', () {
      expect(index.stickyAt(560, m), (day: 2, dy: 0.0));
      expect(index.stickyAt(5000, m), (day: 2, dy: 0.0));
    });

    test('an empty list pins nothing', () {
      expect(HistoryTimelineIndex(const []).stickyAt(10, m), isNull);
    });
  });
}
