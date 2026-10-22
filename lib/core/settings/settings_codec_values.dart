// Helpers shared by the settings codecs. Each reads one JSON value and
// never fails: a value of the wrong type gives the fallback.

/// Doubles from here up are whole numbers, and `truncate` would saturate.
const _twoPow53 = 9007199254740992.0;

bool boolOr(Object? value, bool fallback) => value is bool ? value : fallback;

T enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// An integer in [min]..[max]: a number outside is moved to the nearest
/// bound. A whole number written as `5.0` counts; anything else (a string, a
/// fraction, null) gives [fallback].
int intInRange(Object? value, int min, int max, int fallback) {
  final int number;
  if (value is int) {
    number = value;
  } else if (value is double && value.abs() >= _twoPow53) {
    // Too big for an exact int and always whole (so is +-Infinity): past
    // every bound.
    number = value.isNegative ? min : max;
  } else if (value is double && value.isFinite && value == value.truncate()) {
    number = value.toInt();
  } else {
    return fallback;
  }
  return number.clamp(min, max);
}

/// A number in [min]..[max], moved to the nearest bound when outside. A
/// non-number or a non-finite one gives [fallback].
double doubleInRange(Object? value, double min, double max, double fallback) {
  if (value is! num || !value.isFinite) return fallback;
  return value.toDouble().clamp(min, max);
}

/// [json] as an object, or an empty one: a group of keys that was stored as
/// something else reads as all defaults.
Map<String, Object?> objectOrEmpty(Object? json) =>
    json is Map<String, Object?> ? json : const {};

/// The entries of [json] whose key is not in [known], to be written back.
Map<String, Object?> unknownEntries(
  Map<String, Object?> json,
  Set<String> known,
) => {
  for (final MapEntry(:key, :value) in json.entries)
    if (!known.contains(key)) key: value,
};
