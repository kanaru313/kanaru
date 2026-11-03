import '../../../core/stats/listen_clear_scope.dart';
import '../history_days.dart';

/// What the Clear history dialog offers to remove.
enum HistoryClearRange {
  lastHour,
  today,
  days7,
  everything;

  /// The plays this option removes, as epoch-ms bounds `[from, to)`, all
  /// taken from one [now] so the count shown and the delete agree. The end is
  /// one millisecond after [now], which makes the range include [now]. Days
  /// are local calendar days (a 23 or 25 hour day is still one); Everything
  /// has no bounds.
  ClearBounds bounds(DateTime now) {
    final end = now.millisecondsSinceEpoch + 1;
    switch (this) {
      case HistoryClearRange.lastHour:
        return (
          from: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
          to: end,
        );
      case HistoryClearRange.today:
        return (from: localDay(now).millisecondsSinceEpoch, to: end);
      case HistoryClearRange.days7:
        return (
          from: addDays(localDay(now), -6).millisecondsSinceEpoch,
          to: end,
        );
      case HistoryClearRange.everything:
        return (from: null, to: null);
    }
  }
}
