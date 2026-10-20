import '../../../core/database/artist_names.dart';
import '../../../core/database/library_database.dart';

/// One artist of the Artists list.
class ArtistSummary {
  const ArtistSummary({
    required this.key,
    required this.name,
    required this.songCount,
    required this.albumCount,
  });

  /// `artistKey(name)`; identifies the artist page.
  final String key;

  /// The [preferredSpelling] among the tracks.
  final String name;
  final int songCount;

  /// Albums holding at least one of the artist's tracks.
  final int albumCount;
}

/// Splits each `artist` value into names (guests included, see
/// `splitArtists`) and merges them by key: a track counts once per name, and
/// the albums of every value are united. Names only found as album artist
/// are not artists here.
List<ArtistSummary> buildArtistSummaries(List<ArtistCredit> credits) {
  final names = <String, String>{};
  final songs = <String, int>{};
  final albums = <String, Set<AlbumKey>>{};
  for (final credit in credits) {
    // splitArtists already drops repeated names within one value.
    for (final name in splitArtists(credit.artist)) {
      final key = artistKey(name);
      names[key] = preferredSpelling(names[key], name);
      songs[key] = (songs[key] ?? 0) + credit.trackCount;
      (albums[key] ??= {}).addAll(credit.albumKeys);
    }
  }
  return [
    for (final MapEntry(:key, value: name) in names.entries)
      ArtistSummary(
        key: key,
        name: name,
        songCount: songs[key]!,
        albumCount: albums[key]!.length,
      ),
  ];
}

/// Of two spellings of one artist (same key), the one shown: the smallest
/// by code units, like album titles. Any track order gives the same name,
/// on the list and on the artist page.
String preferredSpelling(String? current, String candidate) =>
    current == null || candidate.compareTo(current) < 0 ? candidate : current;
