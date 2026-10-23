/// How artist tags name several artists in one string, and the keys that
/// identify an artist. The only source of these rules: the scan and the key
/// backfill store the results through `trackKeysFor` (`track_keys.dart`).
library;

import 'separator_rules.dart';
import 'text_keys.dart';

export 'separator_rules.dart' show SplitRules, defaultArtistRules;
export 'text_keys.dart' show maxKeyLength;

/// The artist names in an `artist` or `album_artist` tag, in order, trimmed,
/// without empty parts and without repeats (compared by [artistKey], so `Beyoncé` spelled with a
/// combining accent is the same artist, while `Anh` and `Ánh` are two).
///
/// With the default [rules] it splits on `;` (however spaced), ` feat. `,
/// ` ft. `, ` featuring `, ` with ` (any case, dot optional, any whitespace
/// around) and `/`, except in names of the rules' keep-whole list such as
/// `AC/DC`. A bracketed featuring part (`A (feat. B)`) gives its names too.
/// It never splits on `,` or `&`, which are often part of one name. Control
/// characters count as spaces.
List<String> splitArtists(
  String? tag, {
  SplitRules rules = defaultArtistRules,
}) {
  if (tag == null || tag.isEmpty) return const [];
  final text = withoutControlChars(tag);
  final splitter = rules.splitter;
  // Most tags name one artist; skip the pattern for them.
  if (!splitter.maySplit(text, brackets: true)) {
    final name = text.trim();
    return name.isEmpty ? const [] : [name];
  }
  final names = <String>[];
  final keys = <String>{};
  for (final name in splitter.split(text, brackets: true)) {
    if (keys.add(artistKey(name))) names.add(name);
  }
  return names;
}

/// The key of one artist name: its [groupKey].
String artistKey(String name) => groupKey(name);

/// The keys of every artist in [tag].
List<String> artistKeys(String? tag, {SplitRules rules = defaultArtistRules}) =>
    [for (final name in splitArtists(tag, rules: rules)) artistKey(name)];
