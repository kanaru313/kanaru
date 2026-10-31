/// A release date split into the parts a tag actually gave.
class ReleaseDate {
  const ReleaseDate({required this.year, this.month, this.day});

  final int year;

  /// 1 to 12; null when the tag has no valid month.
  final int? month;

  /// Valid for [month] (leap years included); null when the tag has no valid
  /// day. Only set together with [month].
  final int? day;

  @override
  bool operator ==(Object other) =>
      other is ReleaseDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'ReleaseDate($year, $month, $day)';
}

// Year, then month and day either both dashed or both bare, then an optional
// time after `T` or a space (ignored). A dash/bare mix fails the optional
// groups and leaves the year alone.
final _datePattern = RegExp(
  r'^(\d{4})(?:-(\d{2})(?:-(\d{2}))?|(\d{2})(?:(\d{2}))?)?(?=$|[T ])',
);

/// Parses the raw tag value: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`, `YYYYMM` or
/// `YYYYMMDD`, each optionally followed by `T` or a space and a time.
///
/// Returns null without four leading digits or for year `0000`. A month
/// outside 1 to 12 gives the year only; a day not in the month gives year and
/// month. Mixed separators (`2019-0715`) give the year only.
ReleaseDate? parseReleaseDate(String raw) {
  final text = raw.trim();
  final match = _datePattern.firstMatch(text);
  if (match == null) {
    // Four digits followed by anything else (`2019-0715`, `2019/07`) still
    // has a usable year.
    final head = RegExp(r'^\d{4}').firstMatch(text);
    return head == null ? null : _build(int.parse(head[0]!), null, null);
  }
  final year = int.parse(match[1]!);
  final month = match[2] ?? match[4];
  final day = match[3] ?? match[5];
  return _build(
    year,
    month == null ? null : int.parse(month),
    day == null ? null : int.parse(day),
  );
}

ReleaseDate? _build(int year, int? month, int? day) {
  if (year == 0) return null;
  if (month == null || month < 1 || month > 12) {
    return ReleaseDate(year: year);
  }
  if (day == null || day < 1 || day > DateTime.utc(year, month + 1, 0).day) {
    return ReleaseDate(year: year, month: month);
  }
  return ReleaseDate(year: year, month: month, day: day);
}
