/// Compares two optional values for a user-chosen sort: unknown (`null`)
/// values go last whichever the direction; [descending] flips known ones.
int compareNullsLast<T extends Comparable<Object>>(
  T? a,
  T? b, {
  bool descending = false,
}) {
  if (a == null || b == null) {
    if (a == b) return 0;
    return a == null ? 1 : -1;
  }
  final order = a.compareTo(b);
  return descending ? -order : order;
}

/// Case-insensitive text comparison, the same in both directions as
/// [compareNullsLast].
int compareText(String? a, String? b, {bool descending = false}) =>
    compareNullsLast(
      a?.toLowerCase(),
      b?.toLowerCase(),
      descending: descending,
    );
