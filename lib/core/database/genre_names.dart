import 'separator_rules.dart';
import 'text_keys.dart';

export 'separator_rules.dart' show SplitRules, defaultGenreRules;

/// Identifies a genre: [name] with case, accents and width folded, so "Nhạc
/// Trẻ" and "nhac tre" are one genre. Empty when [name] has nothing to
/// compare (blank or only invisible characters).
String genreKey(String name) => sortKey(name);

/// The genres named in a stored genre string: split by [rules] (by default on
/// `;`), trimmed, without empty parts, and without repeats by [genreKey]
/// (the first spelling stays). Empty for null. Separators are literal text,
/// not patterns; see [SplitRules] for how words and symbols differ.
List<String> splitGenres(String? tag, {SplitRules rules = defaultGenreRules}) {
  if (tag == null) return const [];
  final splitter = rules.splitter;
  final parts = splitter.maySplit(tag, brackets: false)
      ? splitter.split(tag, brackets: false)
      : [tag.trim()];
  final seen = <String>{};
  final genres = <String>[];
  for (final name in parts) {
    final key = genreKey(name);
    if (key.isNotEmpty && seen.add(key)) genres.add(name);
  }
  return genres;
}
