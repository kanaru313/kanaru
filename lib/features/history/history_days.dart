// Local calendar days as the History page needs them. Every step goes through
// the `DateTime(y, m, d)` constructor, never `Duration(days: n)`: a day is 23
// or 25 hours long where the clock changes, and a midnight that does not
// exist moves to the first valid time of that day.

import 'dart:math' as math;

/// Midnight (the first valid time) of the local day [time] falls on.
DateTime localDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// The local day [n] days after [day] (before it when [n] is negative).
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// The day [months] calendar months from [day] (before it when negative),
/// with the day of the month clamped to the target month's last day: 31 Aug
/// minus 6 months is the last day of February.
DateTime addMonthsClamped(DateTime day, int months) {
  final total = day.year * 12 + (day.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day.day, last));
}

/// Calendar days from [a] to [b] (negative when [b] is earlier), counted on
/// dates so a 23 or 25 hour day is still one.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Start of every local day of [year] in epoch ms, then the start of the next
/// year: one more entry than the year has days, so day `i` is
/// `[bounds[i], bounds[i + 1])`.
List<int> dayBoundsOfYear(int year) {
  final bounds = <int>[];
  var day = DateTime(year);
  while (day.year == year) {
    bounds.add(day.millisecondsSinceEpoch);
    day = addDays(day, 1);
  }
  bounds.add(day.millisecondsSinceEpoch);
  return bounds;
}

/// Start of every local day from [first] up to (not including) [endExclusive]
/// in epoch ms, then the start of [endExclusive] itself: day `i` is
/// `[bounds[i], bounds[i + 1])`. Both arguments are taken as the local day
/// they fall on; empty when [endExclusive] is not after [first].
List<int> dayBoundsBetween(DateTime first, DateTime endExclusive) {
  final end = localDay(endExclusive);
  var day = localDay(first);
  if (!day.isBefore(end)) return const [];
  final bounds = <int>[];
  while (day.isBefore(end)) {
    bounds.add(day.millisecondsSinceEpoch);
    day = addDays(day, 1);
  }
  bounds.add(end.millisecondsSinceEpoch);
  return bounds;
}

/// Start of each year from [from] to [to] in epoch ms, then the start of the
/// year after [to]; year `from + i` is `[bounds[i], bounds[i + 1])`.
List<int> yearBounds(int from, int to) => [
  for (var y = from; y <= to + 1; y++) DateTime(y).millisecondsSinceEpoch,
];
