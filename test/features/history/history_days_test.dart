import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_days.dart';

// Run with `TZ=Europe/Berlin` and `TZ=America/Sao_Paulo` to exercise the
// clock changes; without TZ every check still holds for the machine's zone.
final _tz = Platform.environment['TZ'];

DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

/// Every cell of [bounds] starts on its own day, at the first valid time of
/// it, with no gap or overlap: the cell ends where the next starts and the
/// instant before it belongs to the day before.
void _expectDaysTile(List<int> bounds, int year) {
  var day = DateTime(year);
  for (var i = 0; i < bounds.length - 1; i++) {
    expect(_at(bounds[i]).year, day.year, reason: 'cell $i');
    expect(_at(bounds[i]).month, day.month, reason: 'cell $i');
    expect(_at(bounds[i]).day, day.day, reason: 'cell $i');
    expect(bounds[i + 1], greaterThan(bounds[i]), reason: 'cell $i');
    final before = _at(bounds[i] - 1);
    expect(isSameDay(before, day), isFalse, reason: 'cell $i starts late');
    day = addDays(day, 1);
  }
  expect(_at(bounds.last).year, year + 1);
  expect(_at(bounds.last).month, 1);
  expect(_at(bounds.last).day, 1);
}

int _cellHours(List<int> bounds, DateTime day) {
  final i = bounds.indexOf(day.millisecondsSinceEpoch);
  expect(i, isNonNegative, reason: 'no cell starts at $day');
  return Duration(milliseconds: bounds[i + 1] - bounds[i]).inHours;
}

void main() {
  test('addDays steps calendar days, over month and year ends', () {
    expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027));
    expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2024, 3, 1), -1), DateTime(2024, 2, 29));
  });

  test('localDay drops the time and isSameDay compares dates', () {
    final t = DateTime(2026, 5, 6, 23, 59, 59, 999);
    expect(localDay(t), DateTime(2026, 5, 6));
    expect(isSameDay(t, DateTime(2026, 5, 6)), isTrue);
    expect(isSameDay(t, DateTime(2026, 5, 7)), isFalse);
    expect(isSameDay(DateTime(2026, 5, 6), DateTime(2025, 5, 6)), isFalse);
  });

  test('a leap year has 366 cells, others 365', () {
    expect(dayBoundsOfYear(2024), hasLength(367));
    expect(dayBoundsOfYear(2026), hasLength(366));
    expect(dayBoundsOfYear(1900), hasLength(366));
    expect(dayBoundsOfYear(2000), hasLength(367));
  });

  test('the cells of a year tile it day by day', () {
    for (final year in [2024, 2025, 2026]) {
      _expectDaysTile(dayBoundsOfYear(year), year);
    }
  });

  test('a play around midnight falls in the cell of its own day', () {
    final bounds = dayBoundsOfYear(2026);
    final lastMs = DateTime(2026, 6, 15, 23, 59, 59, 999);
    final nextMs = DateTime(2026, 6, 16);
    final i = bounds.indexOf(DateTime(2026, 6, 15).millisecondsSinceEpoch);
    expect(lastMs.millisecondsSinceEpoch, lessThan(bounds[i + 1]));
    expect(nextMs.millisecondsSinceEpoch, bounds[i + 1]);
  });

  test('yearBounds start each year and end after the last', () {
    final bounds = yearBounds(2024, 2026);
    expect(bounds, [
      DateTime(2024).millisecondsSinceEpoch,
      DateTime(2025).millisecondsSinceEpoch,
      DateTime(2026).millisecondsSinceEpoch,
      DateTime(2027).millisecondsSinceEpoch,
    ]);
  });

  group('clock changes', () {
    test('Berlin: 2026-03-29 is 23 h and 2026-10-25 is 25 h', () {
      final bounds = dayBoundsOfYear(2026);
      _expectDaysTile(bounds, 2026);
      // Whatever the zone, a cell is as long as the real time of its day.
      for (final day in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
        expect(
          _cellHours(bounds, day),
          addDays(day, 1).difference(day).inHours,
        );
      }
      if (_tz == 'Europe/Berlin') {
        expect(_cellHours(bounds, DateTime(2026, 3, 29)), 23);
        expect(_cellHours(bounds, DateTime(2026, 10, 25)), 25);
      }
    });

    test('Sao Paulo: the day without a midnight starts at its first hour', () {
      final bounds = dayBoundsOfYear(2018);
      _expectDaysTile(bounds, 2018);
      final day = DateTime(2018, 11, 4);
      expect(bounds, contains(day.millisecondsSinceEpoch));
      expect(day.day, 4);
      if (_tz == 'America/Sao_Paulo') {
        // 00:00 does not exist: the day starts at 01:00.
        expect(day.hour, 1);
        expect(_cellHours(bounds, day), 23);
      }
    });

    test('Sao Paulo: the clock goes back at midnight of 2019-02-17', () {
      final bounds = dayBoundsOfYear(2019);
      _expectDaysTile(bounds, 2019);
      for (final day in [DateTime(2019, 2, 16), DateTime(2019, 2, 17)]) {
        expect(
          _cellHours(bounds, day),
          addDays(day, 1).difference(day).inHours,
        );
      }
      if (_tz == 'America/Sao_Paulo') {
        // 00:00 on the 17th is 23:00 on the 16th again: the 16th is the
        // 25 h day, and the 17th starts at a normal midnight.
        expect(_cellHours(bounds, DateTime(2019, 2, 16)), 25);
        expect(_cellHours(bounds, DateTime(2019, 2, 17)), 24);
      }
    });

    test(
      'stepping a day from the shifted midnight still lands on the next',
      () {
        final day = localDay(DateTime(2018, 11, 4, 12));
        expect(addDays(day, 1), DateTime(2018, 11, 5));
        expect(addDays(day, -1), DateTime(2018, 11, 3));
      },
    );
  });
}
