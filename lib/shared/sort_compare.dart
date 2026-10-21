/// Compares two strings by code point, the way SQLite does. `String.compareTo`
/// compares UTF-16 units, which puts a surrogate pair (U+10000 and up, such as
/// emoji) before U+E000-U+FFFF; Albums and Artists must order like Songs.
int compareCodePoints(String a, String b) {
  final shorter = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < shorter; i++) {
    final x = a.codeUnitAt(i), y = b.codeUnitAt(i);
    if (x == y) continue;
    // Below the surrogates the unit is the code point; only when both are
    // at or above U+D800 can the orders differ. Surrogates then move above
    // U+E000-U+FFFF, as the code points they stand for are.
    if (x < 0xD800 || y < 0xD800) return x - y;
    return _aboveBmp(x) - _aboveBmp(y);
  }
  return a.length - b.length;
}

int _aboveBmp(int unit) => unit >= 0xE000 ? unit - 0x800 : unit + 0x2000;

/// Compares two optional values for a user-chosen sort: unknown (`null`)
/// values go last whichever the direction; [descending] flips known ones.
/// Strings compare by [compareCodePoints].
int compareNullsLast<T extends Comparable<Object>>(
  T? a,
  T? b, {
  bool descending = false,
}) {
  if (a == null || b == null) {
    if (a == b) return 0;
    return a == null ? 1 : -1;
  }
  final order = a is String && b is String
      ? compareCodePoints(a, b)
      : a.compareTo(b);
  return descending ? -order : order;
}
