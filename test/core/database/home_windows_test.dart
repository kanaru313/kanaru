import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/home_windows.dart';

int _ms(int y, int m, int d, [int h = 0, int mi = 0]) =>
    DateTime(y, m, d, h, mi).millisecondsSinceEpoch;

void main() {
  group('memoriesWindow', () {
    test('same day last year, three days each side, end exclusive', () {
      final w = memoriesWindow(DateTime(2026, 10, 23, 15, 30));
      expect(w.start, _ms(2025, 10, 20));
      expect(w.end, _ms(2025, 10, 27));
    });

    test('Feb 29 anchors on Feb 28 of the previous year', () {
      final w = memoriesWindow(DateTime(2028, 2, 29));
      expect(w.start, _ms(2027, 2, 25));
      expect(w.end, _ms(2027, 3, 4));
    });

    test('crosses the year boundary', () {
      final w = memoriesWindow(DateTime(2026, 1, 2));
      expect(w.start, _ms(2024, 12, 30));
      expect(w.end, _ms(2025, 1, 6));
    });

    test('bounds are local midnights, calendar days apart', () {
      // Whatever the machine zone is, the bounds are local midnights.
      final w = memoriesWindow(DateTime(2026, 3, 29));
      expect(
        DateTime.fromMillisecondsSinceEpoch(w.start),
        DateTime(2025, 3, 26),
      );
      expect(DateTime.fromMillisecondsSinceEpoch(w.end), DateTime(2025, 4, 2));
    });

    // Only bites in a zone with DST: a fixed 7 x 24 h step would then land an
    // hour off midnight. In zones without DST the test has nothing to prove.
    test('stays on midnights across a DST change when the zone has one', () {
      final days = [for (var d = 0; d < 366; d++) DateTime(2025, 1, 1 + d)];
      final hasDst = days.any(
        (d) => d.timeZoneOffset != days.first.timeZoneOffset,
      );
      if (!hasDst) return;
      for (final day in days) {
        final w = memoriesWindow(DateTime(day.year + 1, day.month, day.day));
        for (final ms in [w.start, w.end]) {
          final t = DateTime.fromMillisecondsSinceEpoch(ms);
          expect(t, DateTime(t.year, t.month, t.day), reason: '$day');
        }
      }
    });
  });

  group('HomeAddedWindow', () {
    test('slugs round trip and unknown values are null', () {
      for (final w in HomeAddedWindow.values) {
        expect(HomeAddedWindow.fromSlug(w.slug), w);
      }
      expect(HomeAddedWindow.values.map((w) => w.slug), [
        '1d',
        '3d',
        '7d',
        '30d',
        'all',
      ]);
      expect(HomeAddedWindow.fromSlug('2d'), isNull);
      expect(HomeAddedWindow.fromSlug(null), isNull);
    });

    test('since is the same clock time N calendar days ago', () {
      final now = DateTime(2026, 10, 23, 15, 30, 5, 7);
      expect(
        addedWindowSince(HomeAddedWindow.day3, now),
        DateTime(2026, 10, 20, 15, 30, 5, 7).millisecondsSinceEpoch,
      );
      expect(
        addedWindowSince(HomeAddedWindow.day30, now),
        DateTime(2026, 9, 23, 15, 30, 5, 7).millisecondsSinceEpoch,
      );
      expect(addedWindowSince(HomeAddedWindow.all, now), isNull);
    });
  });

  group('defaultAddedWindow', () {
    final now = DateTime(2026, 10, 23, 12);

    test('none or older than 30 days gives all', () {
      expect(defaultAddedWindow(null, now), HomeAddedWindow.all);
      expect(
        defaultAddedWindow(_ms(2026, 9, 23, 11, 59), now),
        HomeAddedWindow.all,
      );
    });

    test('picks the smallest window holding the newest track', () {
      expect(
        defaultAddedWindow(_ms(2026, 10, 23, 11), now),
        HomeAddedWindow.day1,
      );
      expect(defaultAddedWindow(_ms(2026, 10, 21), now), HomeAddedWindow.day3);
      expect(defaultAddedWindow(_ms(2026, 10, 17), now), HomeAddedWindow.day7);
      expect(defaultAddedWindow(_ms(2026, 10, 1), now), HomeAddedWindow.day30);
    });

    test('newest exactly at since belongs to that window', () {
      for (final w in [
        HomeAddedWindow.day1,
        HomeAddedWindow.day3,
        HomeAddedWindow.day7,
        HomeAddedWindow.day30,
      ]) {
        expect(defaultAddedWindow(addedWindowSince(w, now), now), w);
      }
      final justBefore = addedWindowSince(HomeAddedWindow.day1, now)! - 1;
      expect(defaultAddedWindow(justBefore, now), HomeAddedWindow.day3);
    });
  });
}
