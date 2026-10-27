import '../lyrics/lyrics.dart';
import 'translation_language.dart';

/// Most unique lines one translation job will send.
const maxTranslatedLines = 1000;

/// Most characters (summed over unique lines) one translation job will send.
const maxTranslatedChars = 20000;

/// The distinct non-blank line texts of [lyrics], in first-appearance order.
/// A repeated chorus is sent once.
List<String> uniqueLineTexts(Lyrics lyrics) {
  final seen = <String>{};
  return [
    for (final line in lyrics.lines)
      if (line.text.trim().isNotEmpty && seen.add(line.text)) line.text,
  ];
}

/// Splits [lines] into consecutive chunks of at most [maxItems] lines and
/// [maxChars] characters. A single line longer than [maxChars] is its own
/// chunk. Order is kept.
List<List<String>> chunkLines(
  List<String> lines, {
  required int maxItems,
  required int maxChars,
}) {
  assert(maxItems > 0 && maxChars > 0, 'chunk caps must be positive');
  final chunks = <List<String>>[];
  var current = <String>[];
  var chars = 0;
  for (final line in lines) {
    final full =
        current.length >= maxItems ||
        (current.isNotEmpty && chars + line.length > maxChars);
    if (full) {
      chunks.add(current);
      current = <String>[];
      chars = 0;
    }
    current.add(line);
    chars += line.length;
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// One translation per entry of [lines], looked up in [translations] by exact
/// line text. `null` for a blank line, a line with no translation, an empty
/// translation, or a translation that only repeats the source (ignoring case
/// and surrounding spaces), so the screen shows nothing extra there.
List<String?> alignTranslations(
  List<LyricLine> lines,
  Map<String, String> translations,
) => [
  for (final line in lines) _translationOf(line.text, translations[line.text]),
];

String? _translationOf(String source, String? translated) {
  if (source.trim().isEmpty || translated == null) return null;
  final trimmed = translated.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.toLowerCase() == source.trim().toLowerCase()) return null;
  return translated;
}

/// The base language code (see [baseLanguageOf]) covering the most characters
/// of [lines], where [detected] is the language found for each line (`null`
/// when unknown). `null` when no line has a detected language. On a tie the
/// language seen first wins.
String? dominantLanguage(List<String> lines, List<String?> detected) {
  final weights = <String, int>{};
  final count = lines.length < detected.length ? lines.length : detected.length;
  for (var i = 0; i < count; i++) {
    final code = detected[i];
    if (code == null || code.isEmpty) continue;
    final base = baseLanguageOf(code);
    weights[base] = (weights[base] ?? 0) + lines[i].length;
  }
  String? best;
  var bestWeight = -1;
  weights.forEach((code, weight) {
    if (weight > bestWeight) {
      best = code;
      bestWeight = weight;
    }
  });
  return best;
}
