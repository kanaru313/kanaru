/// How artist tags name several artists in one string, and the keys that
/// identify an artist. The only source of these rules: SQL reaches them
/// through the functions in `library_sql_functions.dart`.
library;

/// Names containing `/` that are one artist, lower-cased. Matched only as
/// whole names: `Shellac/DC Talk` still splits.
const slashNameExceptions = {'ac/dc'};

/// Longest key kept, in characters, so route keys stay bounded even for
/// huge tags.
const maxKeyLength = 256;

/// `feat.`, `ft.` (dot optional), `featuring`, `with`.
const _featuring = r'(?:feat\.?|ft\.?|featuring|with)';

/// `A (feat. B)` or `A [ft. B]`: the bracketed part becomes a plain name.
final _bracketedFeaturing = RegExp(
  '\\s*[(\\[]\\s*$_featuring\\s+([^)\\]]*)[)\\]]',
  caseSensitive: false,
);

/// `;` with any spacing, or a featuring word with whitespace on each side.
final _separator = RegExp(
  '\\s*;\\s*|\\s+$_featuring\\s+',
  caseSensitive: false,
);

/// Whitespace followed by the first letter of a featuring word: the cheap
/// test of whether [_separator] may match.
final _maybeFeaturing = RegExp(r'\s[fw]', caseSensitive: false);

/// How many `/`-separated pieces each exception spans, longest first.
final _exceptionSpans = {
  for (final name in slashNameExceptions) name.split('/').length,
}.toList()..sort((a, b) => b - a);

/// The artist names in an `artist` or `album_artist` tag, in order, trimmed,
/// without empty parts and without repeats (compared by [artistKey]).
///
/// Splits on `;` (however spaced), ` feat. `, ` ft. `, ` featuring `,
/// ` with ` (any case, dot optional, any whitespace around) and `/`, except
/// in names of [slashNameExceptions] such as `AC/DC`. A bracketed featuring
/// part (`A (feat. B)`) gives its names too. Never splits on `,` or `&`,
/// which are often part of one name. Control characters count as spaces.
List<String> splitArtists(String? tag) {
  if (tag == null || tag.isEmpty) return const [];
  var text = withoutControlChars(tag);
  // Most tags name one artist; skip the regular expressions for them.
  if (!_mayHoldSeveral(text)) {
    final name = text.trim();
    return name.isEmpty ? const [] : [name];
  }
  if (text.contains('(') || text.contains('[')) {
    text = text.replaceAllMapped(_bracketedFeaturing, (m) => '; ${m[1]}');
  }

  final names = <String>[];
  final keys = <String>{};
  for (final part in text.split(_separator)) {
    for (final piece in _splitSlashes(part)) {
      final name = piece.trim();
      if (name.isNotEmpty && keys.add(artistKey(name))) names.add(name);
    }
  }
  return names;
}

/// [part] split on `/`, keeping runs of pieces that form an exception.
List<String> _splitSlashes(String part) {
  final pieces = part.split('/');
  if (pieces.length == 1) return pieces;
  final out = <String>[];
  var i = 0;
  next:
  while (i < pieces.length) {
    for (final span in _exceptionSpans) {
      if (span < 2 || i + span > pieces.length) continue;
      final joined = pieces.sublist(i, i + span).join('/');
      if (slashNameExceptions.contains(joined.trim().toLowerCase())) {
        out.add(joined);
        i += span;
        continue next;
      }
    }
    out.add(pieces[i++]);
  }
  return out;
}

/// Whether [tag] has something that may separate names: `;`, `/`, a
/// bracket, or a featuring word after whitespace. A cheap check before the
/// regular expressions, which cost far more per tag.
bool _mayHoldSeveral(String tag) =>
    tag.contains(';') ||
    tag.contains('/') ||
    tag.contains('(') ||
    tag.contains('[') ||
    tag.contains(_maybeFeaturing);

/// [text] with control characters (U+0000–U+001F, U+007F) replaced by
/// spaces: tags may hold tabs or NULs, and keys must never contain the
/// characters the queries use as delimiters.
String withoutControlChars(String text) {
  for (final unit in text.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) {
      return String.fromCharCodes([
        for (final u in text.codeUnits) u < 0x20 || u == 0x7f ? 0x20 : u,
      ]);
    }
  }
  return text;
}

/// The key of one artist name: [textKey] of it.
String artistKey(String name) => textKey(name);

/// A key made from user text: no control characters, lower case (Unicode),
/// at most [maxKeyLength] characters.
String textKey(String text) => cutKey(withoutControlChars(text).toLowerCase());

/// [key] cut to [maxKeyLength] characters (not UTF-16 units, so a
/// character is never split).
String cutKey(String key) {
  final runes = key.runes;
  return runes.length <= maxKeyLength
      ? key
      : String.fromCharCodes(runes.take(maxKeyLength));
}

/// The keys of every artist in [tag].
List<String> artistKeys(String? tag) => [
  for (final name in splitArtists(tag)) artistKey(name),
];
