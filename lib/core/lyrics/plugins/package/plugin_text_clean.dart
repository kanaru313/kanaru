// Control characters (Cc), format characters (Cf: bidi overrides and
// isolates, zero-width characters, BOM) and line/paragraph separators.
final _unwanted = RegExp(r'[\p{Cc}\p{Cf}\u2028\u2029]', unicode: true);
// The same, except a line feed.
final _unwantedKeepNewline = RegExp(
  r'(?!\n)\p{Cc}|[\p{Cf}\u2028\u2029]',
  unicode: true,
);

/// [text] without characters that could spoof or break a dialog, trimmed.
/// Lengths in the plugin rules count Unicode code points (`runes`).
String cleanPluginText(String text, {bool keepNewlines = false}) =>
    text.replaceAll(keepNewlines ? _unwantedKeepNewline : _unwanted, '').trim();

/// [text] cleaned and cut to [maxRunes] code points, for echoing attacker
/// text in a problem detail.
String limitPluginText(String text, int maxRunes) {
  final cleaned = text.replaceAll(_unwanted, '?');
  if (cleaned.runes.length <= maxRunes) return cleaned;
  return String.fromCharCodes(cleaned.runes.take(maxRunes));
}
