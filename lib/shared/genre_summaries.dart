import '../core/database/genre_names.dart';
import 'library_route_keys.dart' show unknownGenreKey;
import 'artist_summaries.dart' show preferredSpelling;
import 'sort_compare.dart';

/// One genre row (Genres list).
class GenreSummary {
  const GenreSummary({
    required this.key,
    required this.name,
    required this.songCount,
    required this.raws,
    this.withoutGenre = false,
    this.coverKeys = const [],
  });

  /// `genreKey(name)`; identifies the genre page. [unknownGenreKey] for the
  /// tracks with no usable genre.
  final String key;

  /// The [preferredSpelling] among the stored strings. Empty for
  /// [unknownGenreKey]: the screens show their own words for it.
  final String name;

  /// Tracks whose stored genre names this genre (a track with several
  /// genres in one string counts once for each).
  final int songCount;

  /// The stored genre strings that name this genre, to query its tracks.
  final List<String> raws;

  /// Whether the genre also holds the tracks with no genre tag at all
  /// (stored as null), which no string in [raws] reaches. Only for
  /// [unknownGenreKey].
  final bool withoutGenre;

  /// Up to four distinct cover keys for the tile collage (`PlaylistCover`).
  /// Empty until a provider fetches them; [buildGenreSummaries] does not.
  final List<String> coverKeys;

  /// This genre with [coverKeys] attached.
  GenreSummary withCoverKeys(List<String> coverKeys) => GenreSummary(
    key: key,
    name: name,
    songCount: songCount,
    raws: raws,
    withoutGenre: withoutGenre,
    coverKeys: coverKeys,
  );
}

/// The list rows for [counts] (stored genre string and its tracks), one per
/// [genreKey], sorted by key, then the row of the tracks with no usable genre
/// (no tag, or a string that names no genre) last, when there are any. A
/// string naming several genres counts for each. [rules] split the strings.
List<GenreSummary> buildGenreSummaries(
  List<({String? raw, int count})> counts, {
  SplitRules rules = defaultGenreRules,
}) {
  final names = <String, String>{};
  final songs = <String, int>{};
  final raws = <String, Set<String>>{};
  var unknownSongs = 0;
  var unknownNull = false;
  final unknownRaws = <String>{};
  for (final (:raw, :count) in counts) {
    final genres = splitGenres(raw, rules: rules);
    if (genres.isEmpty) {
      unknownSongs += count;
      if (raw == null) {
        unknownNull = true;
      } else {
        unknownRaws.add(raw);
      }
      continue;
    }
    for (final name in genres) {
      final key = genreKey(name);
      names[key] = preferredSpelling(names[key], name);
      songs[key] = (songs[key] ?? 0) + count;
      (raws[key] ??= {}).add(raw!);
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
    if (unknownSongs > 0)
      GenreSummary(
        key: unknownGenreKey,
        name: '',
        songCount: unknownSongs,
        raws: unknownRaws.toList()..sort(compareCodePoints),
        withoutGenre: unknownNull,
      ),
  ];
}
