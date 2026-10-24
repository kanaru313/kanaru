// Pure time windows of the Home page. Every bound is an epoch-ms value built
// from local calendar dates (`DateTime(y, m, d)`), so a day is 23, 24 or 25
// hours on DST changes and the arithmetic never uses fixed 24 h steps.

/// Half-open range `[start, end)` in epoch ms around the same calendar day of
/// the previous year: three days before the anchor up to three days after it.
/// Feb 29 uses Feb 28 because the previous year has no Feb 29.
({int start, int end}) memoriesWindow(DateTime now) {
  final year = now.year - 1;
  final leapDay = now.month == DateTime.february && now.day == 29;
  final month = now.month;
  final day = leapDay ? 28 : now.day;
  return (
    start: DateTime(year, month, day - 3).millisecondsSinceEpoch,
    end: DateTime(year, month, day + 4).millisecondsSinceEpoch,
  );
}

/// The "recently added" chips, smallest window first.
enum HomeAddedWindow {
  day1('1d', 1),
  day3('3d', 3),
  day7('7d', 7),
  day30('30d', 30),
  all('all', null);

  const HomeAddedWindow(this.slug, this.days);

  /// Stable text for the URL.
  final String slug;

  /// Calendar days back, null for [all].
  final int? days;

  /// The window with [slug]; null for an unknown or missing value.
  static HomeAddedWindow? fromSlug(String? slug) {
    for (final w in values) {
      if (w.slug == slug) return w;
    }
    return null;
  }
}

/// The oldest `added_at` (epoch ms) that [window] includes; null for
/// [HomeAddedWindow.all]. Same wall-clock time N calendar days ago.
int? addedWindowSince(HomeAddedWindow window, DateTime now) {
  final days = window.days;
  if (days == null) return null;
  return DateTime(
    now.year,
    now.month,
    now.day - days,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
  ).millisecondsSinceEpoch;
}

/// The smallest window that still holds the newest track added
/// ([newestAddedAt]); [HomeAddedWindow.all] when there is none or it is older
/// than 30 days.
HomeAddedWindow defaultAddedWindow(int? newestAddedAt, DateTime now) {
  if (newestAddedAt == null) return HomeAddedWindow.all;
  for (final w in HomeAddedWindow.values) {
    final since = addedWindowSince(w, now);
    if (since != null && since <= newestAddedAt) return w;
  }
  return HomeAddedWindow.all;
}
