// Local calendar days as the History page needs them. Every step goes through
// the `DateTime(y, m, d)` constructor, never `Duration(days: n)`: a day is 23
// or 25 hours long where the clock changes, and a midnight that does not
// exist moves to the first valid time of that day.

/// Midnight (the first valid time) of the local day [time] falls on.
DateTime localDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// The local day [n] days after [day] (before it when [n] is negative).
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

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

/// Start of each year from [from] to [to] in epoch ms, then the start of the
/// year after [to]; year `from + i` is `[bounds[i], bounds[i + 1])`.
List<int> yearBounds(int from, int to) => [
  for (var y = from; y <= to + 1; y++) DateTime(y).millisecondsSinceEpoch,
];
