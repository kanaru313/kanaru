import 'history_days.dart';

/// The ranges the Most played page offers.
enum HistoryRangePreset { today, days7, days30, months6, year, all, custom }

/// Most plays shown on the Most played page.
const historyTopLimit = 500;

/// The range of the Most played page: a [preset], and how many periods back
/// from it (`back`, 0 is the current one) the user stepped.
///
/// Every range is whole local calendar days ending at midnight after today
/// (or, for a custom range, after the day the user picked). 6 months and
/// 1 year are rolling windows of calendar days, not calendar years; a calendar
/// year is a custom range. Periods follow one another with no gap or overlap:
/// the start of period `k` is the end of period `k + 1`.
class HistoryRangeState {
  const HistoryRangeState({
    this.preset = HistoryRangePreset.days30,
    this.back = 0,
    this.customStart,
    this.customEndInclusive,
  });

  final HistoryRangePreset preset;

  /// Periods before the current one. Negative only for a custom range moved
  /// past its own end.
  final int back;

  /// First and last day of the custom range (local midnights); set with
  /// [HistoryRangePreset.custom].
  final DateTime? customStart;
  final DateTime? customEndInclusive;

  /// The first day and the day after the last one, or null for all time.
  ({DateTime start, DateTime end})? days(DateTime now) {
    final today = localDay(now);
    switch (preset) {
      case HistoryRangePreset.all:
        return null;
      case HistoryRangePreset.today:
        return _byDays(today, 1);
      case HistoryRangePreset.days7:
        return _byDays(today, 7);
      case HistoryRangePreset.days30:
        return _byDays(today, 30);
      case HistoryRangePreset.months6:
        return _byMonths(today, 6);
      case HistoryRangePreset.year:
        return _byMonths(today, 12);
      case HistoryRangePreset.custom:
        final a = customStart;
        final b = customEndInclusive;
        if (a == null || b == null) return null;
        final end = addDays(b, 1);
        final length = daysBetween(a, end);
        return (
          start: addDays(a, -back * length),
          end: addDays(end, -back * length),
        );
    }
  }

  ({DateTime start, DateTime end}) _byDays(DateTime today, int n) {
    final end = addDays(today, 1 - back * n);
    return (start: addDays(end, -n), end: end);
  }

  ({DateTime start, DateTime end}) _byMonths(DateTime today, int m) => (
    start: addDays(addMonthsClamped(today, -(back + 1) * m), 1),
    end: addDays(addMonthsClamped(today, -back * m), 1),
  );

  /// The window in epoch ms, `[start, end)`; null for all time.
  ({int start, int end})? window(DateTime now) {
    final d = days(now);
    return d == null
        ? null
        : (
            start: d.start.millisecondsSinceEpoch,
            end: d.end.millisecondsSinceEpoch,
          );
  }

  /// Whether the next period exists: the current one does not reach today yet.
  bool canGoNext(DateTime now) {
    final d = days(now);
    return d != null && d.end.isBefore(addDays(localDay(now), 1));
  }

  bool get canGoPrevious => preset != HistoryRangePreset.all;

  HistoryRangeState previous() => _moved(back + 1);

  HistoryRangeState next() => _moved(back - 1);

  HistoryRangeState _moved(int back) => HistoryRangeState(
    preset: preset,
    back: back,
    customStart: customStart,
    customEndInclusive: customEndInclusive,
  );

  /// [preset] at its current period; a custom range stays remembered.
  HistoryRangeState withPreset(HistoryRangePreset preset) => HistoryRangeState(
    preset: preset,
    customStart: customStart,
    customEndInclusive: customEndInclusive,
  );

  /// The custom range from day [start] to day [endInclusive].
  HistoryRangeState withCustom(DateTime start, DateTime endInclusive) =>
      HistoryRangeState(
        preset: HistoryRangePreset.custom,
        customStart: localDay(start),
        customEndInclusive: localDay(endInclusive),
      );
}

/// The days the range picker may offer: from the first play (or today, when
/// that is earlier) to the last play (or today). A clock that was wrong can
/// leave plays in the future.
({DateTime first, DateTime last}) pickerBounds(
  ({int first, int last}) played,
  DateTime now,
) {
  final today = localDay(now);
  final first = localDay(DateTime.fromMillisecondsSinceEpoch(played.first));
  final last = localDay(DateTime.fromMillisecondsSinceEpoch(played.last));
  return (
    first: first.isBefore(today) ? first : today,
    last: last.isAfter(today) ? last : today,
  );
}

/// The custom range of [state] cut to [bounds], for the picker's initial
/// selection; null when none is left (the picker asserts on dates outside
/// its bounds).
({DateTime start, DateTime end})? clampedCustom(
  HistoryRangeState state,
  ({DateTime first, DateTime last}) bounds,
) {
  final a = state.customStart;
  final b = state.customEndInclusive;
  if (a == null || b == null) return null;
  final start = a.isBefore(bounds.first) ? bounds.first : a;
  final end = b.isAfter(bounds.last) ? bounds.last : b;
  return end.isBefore(start) ? null : (start: start, end: end);
}

/// Whether [window] takes in every play in [played], so the all-time list
/// (cheaper to read, the same answer) can stand in for it.
bool windowCoversPlays(
  ({int start, int end}) window,
  ({int first, int last}) played,
) => window.start <= played.first && window.end > played.last;
