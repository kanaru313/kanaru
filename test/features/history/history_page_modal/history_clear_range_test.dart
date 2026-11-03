import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_page_modal/history_clear_range.dart';

int _ms(DateTime t) => t.millisecondsSinceEpoch;

void main() {
  final now = DateTime(2026, 10, 23, 15, 30, 12, 345);

  test('last hour runs from an hour before now to now, inclusive', () {
    final b = HistoryClearRange.lastHour.bounds(now);
    expect(b.from, _ms(DateTime(2026, 10, 23, 14, 30, 12, 345)));
    expect(b.to, _ms(now) + 1);
  });

  test('today starts at local midnight', () {
    final b = HistoryClearRange.today.bounds(now);
    expect(b.from, _ms(DateTime(2026, 10, 23)));
    expect(b.to, _ms(now) + 1);
  });

  test('last 7 days is today and the 6 days before', () {
    final b = HistoryClearRange.days7.bounds(now);
    expect(b.from, _ms(DateTime(2026, 10, 17)));
    expect(b.to, _ms(now) + 1);
  });

  test('last 7 days steps over month and year ends by date', () {
    final b = HistoryClearRange.days7.bounds(DateTime(2027, 1, 3, 9));
    expect(b.from, _ms(DateTime(2026, 12, 28)));
  });

  test('a play at the exact moment of now is inside, one ms later is not', () {
    final b = HistoryClearRange.today.bounds(now);
    expect(_ms(now) >= b.from! && _ms(now) < b.to!, isTrue);
    expect(_ms(now) + 1 < b.to!, isFalse);
  });

  test('just after midnight today holds only that moment', () {
    final after = DateTime(2026, 10, 24, 0, 0, 1);
    final b = HistoryClearRange.today.bounds(after);
    expect(b.from, _ms(DateTime(2026, 10, 24)));
    // Yesterday's last play stays out.
    expect(_ms(DateTime(2026, 10, 23, 23, 59, 59)) < b.from!, isTrue);
  });

  test('everything has no bounds', () {
    final b = HistoryClearRange.everything.bounds(now);
    expect(b.from, isNull);
    expect(b.to, isNull);
  });

  test('7 days back is built from calendar dates (not 24 h steps)', () {
    // Wherever the machine zone changes its clock, a 23 or 25 hour day must
    // still be one day: the start is always the local midnight 6 days back.
    for (final day in [
      DateTime(2026, 3, 29, 12),
      DateTime(2026, 3, 8, 12),
      DateTime(2026, 11, 1, 12),
      DateTime(2026, 10, 25, 12),
    ]) {
      final b = HistoryClearRange.days7.bounds(day);
      final start = DateTime.fromMillisecondsSinceEpoch(b.from!);
      final back = DateTime(day.year, day.month, day.day - 6);
      expect(start, back);
      expect(start.hour, back.hour);
    }
  });
}
