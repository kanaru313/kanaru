import 'text_keys.dart';

/// What separates genres inside one stored genre string. The scanner keeps
/// the first genre of a file only, so this only matters for tags a person
/// typed as "Rock; Pop".
const defaultGenreSeparators = [';'];

final _separatorPatterns = <String, RegExp>{};

/// One pattern per distinct list of separators, made on first use.
RegExp _patternFor(List<String> separators) => _separatorPatterns.putIfAbsent(
  separators.join('\u0000'),
  () => RegExp('\\s*(?:${separators.map(RegExp.escape).join('|')})\\s*'),
);

/// Identifies a genre: [name] with case, accents and width folded, so "Nhạc
/// Trẻ" and "nhac tre" are one genre. Empty when [name] has nothing to
/// compare (blank or only invisible characters).
String genreKey(String name) => sortKey(name);

/// The genres named in a stored genre string: split on any of [separators]
/// (empty entries ignored), trimmed, without empty parts, and without
/// repeats by [genreKey] (the first spelling stays). Empty for null.
List<String> splitGenres(
  String? tag, {
  List<String> separators = defaultGenreSeparators,
}) {
  if (tag == null) return const [];
  final parts = separators.isEmpty || separators.every((s) => s.isEmpty)
      ? [tag]
      : tag.split(
          _patternFor([
            for (final s in separators)
              if (s.isNotEmpty) s,
          ]),
        );
  final seen = <String>{};
  final genres = <String>[];
  for (final part in parts) {
    final name = part.trim();
    final key = genreKey(name);
    if (key.isNotEmpty && seen.add(key)) genres.add(name);
  }
  return genres;
}
