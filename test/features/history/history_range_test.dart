import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_days.dart';
import 'package:kanaru/features/history/history_range.dart';

// Run with `TZ=Europe/Berlin` and `TZ=America/Sao_Paulo` to exercise the
// clock changes; without TZ every check still holds for the machine's zone.

/// Days that sit on or next to a clock change somewhere, plus ordinary ones.
final _fixtures = [
  DateTime(2026, 10, 23, 12),
  DateTime(2026, 3, 29, 12),
  DateTime(2026, 3, 30, 0, 30),
  DateTime(2026, 10, 25, 12),
  DateTime(2018, 11, 4, 12),
  DateTime(2018, 11, 5, 12),
  DateTime(2019, 2, 16, 12),
  DateTime(2019, 2, 17, 12),
  DateTime(2024, 2, 29, 12),
  DateTime(2026, 8, 31, 23, 59),
];

const _timed = [
  HistoryRangePreset.today,
  HistoryRangePreset.days7,
  HistoryRangePreset.days30,
  HistoryRangePreset.months6,
  HistoryRangePreset.year,
];

HistoryRangeState _at(HistoryRangePreset preset, int back) =>
    HistoryRangeState(preset: preset, back: back);

/// [ms] is the first valid instant of its local day.
void _expectDayStart(int ms, String reason) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  expect(
    isSameDay(DateTime.fromMillisecondsSinceEpoch(ms - 1), t),
    isFalse,
    reason: '$reason: the instant before is the same day',
  );
  expect(t, localDay(t), reason: '$reason: not a day start');
}

void main() {
  group('addMonthsClamped', () {
    test('clamps to the last day of a shorter month', () {
      expect(
        addMonthsClamped(DateTime(2026, 8, 31), -6),
        DateTime(2026, 2, 28),
      );
      expect(
        addMonthsClamped(DateTime(2024, 8, 31), -6),
        DateTime(2024, 2, 29),
      );
      expect(
        addMonthsClamped(DateTime(2024, 2, 29), -12),
        DateTime(2023, 2, 28),
      );
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('crosses year ends in both directions', () {
      expect(
        addMonthsClamped(DateTime(2026, 3, 15), -6),
        DateTime(2025, 9, 15),
      );
      expect(addMonthsClamped(DateTime(2026, 12, 5), 2), DateTime(2027, 2, 5));
      expect(addMonthsClamped(DateTime(2026, 1, 5), -1), DateTime(2025, 12, 5));
      expect(addMonthsClamped(DateTime(2026, 5, 5), 0), DateTime(2026, 5, 5));
    });
  });

  group('presets', () {
    test('the current period ends at midnight after today', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(_at(HistoryRangePreset.today, 0).days(now), (
        start: DateTime(2026, 10, 23),
        end: DateTime(2026, 10, 24),
      ));
      expect(
        _at(HistoryRangePreset.days7, 0).days(now)!.start,
        DateTime(2026, 10, 17),
      );
      expect(
        _at(HistoryRangePreset.days30, 0).days(now)!.start,
        DateTime(2026, 9, 24),
      );
      expect(
        _at(HistoryRangePreset.months6, 0).days(now)!.start,
        DateTime(2026, 4, 24),
      );
      expect(
        _at(HistoryRangePreset.year, 0).days(now)!.start,
        DateTime(2025, 10, 24),
      );
    });

    test('the default is 30 days, the current period', () {
      const state = HistoryRangeState();
      expect(state.preset, HistoryRangePreset.days30);
      expect(state.back, 0);
    });

    test('all time has no window and no neighbours', () {
      final now = DateTime(2026, 10, 23);
      final all = _at(HistoryRangePreset.all, 0);
      expect(all.window(now), isNull);
      expect(all.canGoNext(now), isFalse);
      expect(all.canGoPrevious, isFalse);
    });

    test('periods follow each other with no gap or overlap', () {
      for (final now in _fixtures) {
        for (final preset in _timed) {
          for (var k = 0; k < 4; k++) {
            final here = _at(preset, k).days(now)!;
            final before = _at(preset, k + 1).days(now)!;
            expect(here.start, before.end, reason: '$preset $k at $now');
            expect(here.start.isBefore(here.end), isTrue);
            final w = _at(preset, k).window(now)!;
            final wb = _at(preset, k + 1).window(now)!;
            expect(w.start, wb.end, reason: '$preset $k at $now');
            _expectDayStart(w.start, '$preset $k at $now');
            _expectDayStart(w.end, '$preset $k at $now');
          }
        }
      }
    });

    test('period k of the day presets is k times the length back', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(_at(HistoryRangePreset.days7, 2).days(now), (
        start: DateTime(2026, 10, 3),
        end: DateTime(2026, 10, 10),
      ));
      expect(_at(HistoryRangePreset.today, 1).days(now), (
        start: DateTime(2026, 10, 22),
        end: DateTime(2026, 10, 23),
      ));
    });

    test('6 months from 31 August ends in clamped February', () {
      final now = DateTime(2026, 8, 31, 12);
      final d = _at(HistoryRangePreset.months6, 0).days(now)!;
      expect(d.end, DateTime(2026, 9, 1));
      expect(d.start, DateTime(2026, 3, 1));
      final leap = _at(
        HistoryRangePreset.months6,
        0,
      ).days(DateTime(2024, 8, 31))!;
      expect(leap.start, DateTime(2024, 3, 1));
      final before = _at(HistoryRangePreset.months6, 1).days(now)!;
      expect(before.end, DateTime(2026, 3, 1));
      expect(before.start, DateTime(2025, 9, 1));
    });

    test('1 year from 29 February steps to the clamped 28th', () {
      final now = DateTime(2024, 2, 29, 12);
      final d = _at(HistoryRangePreset.year, 1).days(now)!;
      expect(d.end, DateTime(2023, 3, 1));
      expect(d.start, DateTime(2022, 3, 1));
    });

    test('next is only possible once stepped back', () {
      for (final now in _fixtures) {
        for (final preset in _timed) {
          expect(_at(preset, 0).canGoNext(now), isFalse, reason: '$preset');
          expect(_at(preset, 1).canGoNext(now), isTrue, reason: '$preset');
          expect(_at(preset, 1).next().back, 0);
          expect(_at(preset, 0).previous().back, 1);
        }
      }
    });
  });

  group('custom', () {
    final now = DateTime(2026, 10, 23, 12);

    test('a range is [first day, day after the last)', () {
      final s = const HistoryRangeState().withCustom(
        DateTime(2026, 5, 3, 18),
        DateTime(2026, 5, 12, 2),
      );
      expect(s.preset, HistoryRangePreset.custom);
      expect(s.days(now), (
        start: DateTime(2026, 5, 3),
        end: DateTime(2026, 5, 13),
      ));
    });

    test('a one day and a ten day range shift by their own length', () {
      final one = const HistoryRangeState().withCustom(
        DateTime(2026, 5, 3),
        DateTime(2026, 5, 3),
      );
      expect(one.previous().days(now), (
        start: DateTime(2026, 5, 2),
        end: DateTime(2026, 5, 3),
      ));
      expect(one.next().days(now), (
        start: DateTime(2026, 5, 4),
        end: DateTime(2026, 5, 5),
      ));
      final ten = const HistoryRangeState().withCustom(
        DateTime(2026, 5, 3),
        DateTime(2026, 5, 12),
      );
      expect(ten.previous().days(now), (
        start: DateTime(2026, 4, 23),
        end: DateTime(2026, 5, 3),
      ));
      expect(
        ten.previous().previous().next().days(now),
        ten.previous().days(now),
      );
      expect(ten.next().days(now), (
        start: DateTime(2026, 5, 13),
        end: DateTime(2026, 5, 23),
      ));
    });

    test('shifting over a clock change keeps whole days', () {
      final s = const HistoryRangeState().withCustom(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 30),
      );
      final before = s.previous().days(now)!;
      expect(before.start, DateTime(2026, 3, 25));
      expect(before.end, DateTime(2026, 3, 28));
      _expectDayStart(before.end.millisecondsSinceEpoch, 'end');
    });

    test('next stops once the range reaches today', () {
      final past = const HistoryRangeState().withCustom(
        DateTime(2026, 5, 3),
        DateTime(2026, 5, 12),
      );
      expect(past.canGoNext(now), isTrue);
      final upToToday = const HistoryRangeState().withCustom(
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 23),
      );
      expect(upToToday.canGoNext(now), isFalse);
    });

    test('a preset keeps the custom range for later', () {
      final s = const HistoryRangeState()
          .withCustom(DateTime(2026, 5, 3), DateTime(2026, 5, 12))
          .withPreset(HistoryRangePreset.days7);
      expect(s.back, 0);
      expect(s.withPreset(HistoryRangePreset.custom).days(now), isNotNull);
    });

    test('custom with nothing picked has no window', () {
      expect(_at(HistoryRangePreset.custom, 0).days(now), isNull);
    });
  });

  group('picker bounds', () {
    final now = DateTime(2026, 10, 23, 12);
    ({int first, int last}) played(DateTime a, DateTime b) =>
        (first: a.millisecondsSinceEpoch, last: b.millisecondsSinceEpoch);

    test('run from the first play to today', () {
      final b = pickerBounds(
        played(DateTime(2026, 8, 20, 9), DateTime(2026, 10, 1)),
        now,
      );
      expect(b.first, DateTime(2026, 8, 20));
      expect(b.last, DateTime(2026, 10, 23));
    });

    test('reach a play in the future and a first play today', () {
      final b = pickerBounds(
        played(DateTime(2026, 10, 23, 20), DateTime(2026, 11, 2, 8)),
        now,
      );
      expect(b.first, DateTime(2026, 10, 23));
      expect(b.last, DateTime(2026, 11, 2));
    });

    test('cut the custom range to the bounds, or drop it', () {
      final bounds = (
        first: DateTime(2026, 8, 20),
        last: DateTime(2026, 10, 23),
      );
      final inside = const HistoryRangeState().withCustom(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 5),
      );
      expect(clampedCustom(inside, bounds), (
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      ));
      final wide = const HistoryRangeState().withCustom(
        DateTime(2020),
        DateTime(2030),
      );
      expect(clampedCustom(wide, bounds), (
        start: bounds.first,
        end: bounds.last,
      ));
      final gone = const HistoryRangeState().withCustom(
        DateTime(2020),
        DateTime(2021),
      );
      expect(clampedCustom(gone, bounds), isNull);
      final late = const HistoryRangeState().withCustom(
        DateTime(2027),
        DateTime(2028),
      );
      expect(clampedCustom(late, bounds), isNull);
      expect(clampedCustom(const HistoryRangeState(), bounds), isNull);
    });
  });

  test('a window covers the plays only when it takes in first and last', () {
    final w = (start: 100, end: 200);
    expect(windowCoversPlays(w, (first: 100, last: 199)), isTrue);
    expect(windowCoversPlays(w, (first: 100, last: 200)), isFalse);
    expect(windowCoversPlays(w, (first: 99, last: 150)), isFalse);
    expect(windowCoversPlays(w, (first: 120, last: 130)), isTrue);
  });
}
