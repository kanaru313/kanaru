import '../core/database/genre_names.dart';
import 'artist_summaries.dart' show preferredSpelling;
import 'sort_compare.dart';

/// One genre row (Genres list).
class GenreSummary {
  const GenreSummary({
    required this.key,
    required this.name,
    required this.songCount,
    required this.raws,
  });

  /// `genreKey(name)`; identifies the genre page.
  final String key;

  /// The [preferredSpelling] among the stored strings.
  final String name;

  /// Tracks whose stored genre names this genre (a track with several
  /// genres in one string counts once for each).
  final int songCount;

  /// The stored genre strings that name this genre, to query its tracks.
  final List<String> raws;
}

/// The list rows for [counts] (stored genre string and its tracks), one per
/// [genreKey], sorted by key. A string naming several genres counts for each.
List<GenreSummary> buildGenreSummaries(
  List<({String raw, int count})> counts, {
  List<String> separators = defaultGenreSeparators,
}) {
  final names = <String, String>{};
  final songs = <String, int>{};
  final raws = <String, Set<String>>{};
  for (final (:raw, :count) in counts) {
    for (final name in splitGenres(raw, separators: separators)) {
      final key = genreKey(name);
      names[key] = preferredSpelling(names[key], name);
      songs[key] = (songs[key] ?? 0) + count;
      (raws[key] ??= {}).add(raw);
    }
  }
  final keys = names.keys.toList()..sort(compareCodePoints);
  return [
    for (final key in keys)
      GenreSummary(
        key: key,
        name: names[key]!,
        songCount: songs[key]!,
        raws: raws[key]!.toList()..sort(compareCodePoints),
      ),
  ];
}
