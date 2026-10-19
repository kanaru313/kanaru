/// How artist tags name several artists in one string, and the keys that
/// identify an artist. The only source of these rules: SQL reaches them
/// through the functions in `library_sql_functions.dart`.
library;

/// Names containing `/` that are one artist, lower-cased.
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

/// `;` with any spacing, or a featuring word with a space on each side.
final _separator = RegExp(
  '\\s*;\\s*|\\s+$_featuring\\s+',
  caseSensitive: false,
);

final _slashExceptions = RegExp(
  slashNameExceptions.map(RegExp.escape).join('|'),
  caseSensitive: false,
);

/// Placeholder for a protected name; `\u0000` never appears in tags.
final _placeholder = RegExp('\u0000(\\d+)\u0000');

/// The artist names in an `artist` or `album_artist` tag, in order, trimmed,
/// without empty parts and without repeats (compared by [artistKey]).
///
/// Splits on `;` (however spaced), ` feat. `, ` ft. `, ` featuring `,
/// ` with ` (any case, dot optional) and `/`, except inside
/// [slashNameExceptions] such as `AC/DC`. A bracketed featuring part
/// (`A (feat. B)`) gives its names too. Never splits on `,` or `&`, which
/// are often part of one name.
List<String> splitArtists(String? tag) {
  if (tag == null || tag.isEmpty) return const [];
  // Most tags name one artist; skip the regular expressions for them.
  if (!_mayHoldSeveral(tag)) {
    final name = tag.trim();
    return name.isEmpty ? const [] : [name];
  }
  final protected = <String>[];
  var text = tag;
  if (tag.contains('/')) {
    text = text.replaceAllMapped(_slashExceptions, (m) {
      protected.add(m[0]!);
      return '\u0000${protected.length - 1}\u0000';
    });
  }
  if (tag.contains('(') || tag.contains('[')) {
    text = text.replaceAllMapped(_bracketedFeaturing, (m) => '; ${m[1]}');
  }

  final names = <String>[];
  final keys = <String>{};
  for (final part in text.split(_separator)) {
    for (final piece in part.split('/')) {
      final name = piece
          .replaceAllMapped(_placeholder, (m) => protected[int.parse(m[1]!)])
          .trim();
      if (name.isNotEmpty && keys.add(artistKey(name))) names.add(name);
    }
  }
  return names;
}

/// Whether [tag] has a character or word that may separate names: `;`, `/`,
/// a bracket, or a featuring word after a space. A cheap check before the regular
/// expressions, which cost far more per tag.
bool _mayHoldSeveral(String tag) {
  if (tag.contains(';') ||
      tag.contains('/') ||
      tag.contains('(') ||
      tag.contains('[')) {
    return true;
  }
  for (var i = tag.indexOf(' '); i >= 0; i = tag.indexOf(' ', i + 1)) {
    if (i + 1 < tag.length && _featuringStart.contains(tag[i + 1])) {
      return true;
    }
  }
  return false;
}

/// First letters of the featuring words, any case.
const _featuringStart = {'f', 'F', 'w', 'W'};

/// The key of one artist name: lower case (Unicode), at most
/// [maxKeyLength] characters.
String artistKey(String name) => cutKey(name.toLowerCase());

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
