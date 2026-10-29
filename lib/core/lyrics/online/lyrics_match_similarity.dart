import '../../search/typo_correction.dart';

/// A title or artist at least this similar counts as the same.
const titleSimilarityMin = 0.85;
const artistSimilarityMin = 0.85;

/// `1 - edits / longer length` over code points, 1 for equal strings and 0
/// when more than a fifth of the longer string has to change.
double similarity(String a, String b) {
  if (a == b) return 1;
  final longest = a.runes.length > b.runes.length
      ? a.runes.length
      : b.runes.length;
  final distance = boundedTypoDistance(a, b, (0.2 * longest).floor());
  return distance == null ? 0 : 1 - distance / longest;
}

/// Float rounding must not turn 0.85 into 0.8499999.
bool atLeast(double value, double min) => value + 1e-9 >= min;
