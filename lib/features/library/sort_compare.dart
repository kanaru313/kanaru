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
