import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
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
}
