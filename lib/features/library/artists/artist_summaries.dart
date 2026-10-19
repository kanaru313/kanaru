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

  /// The name lower-cased by SQL; identifies the artist page.
  final String key;

  /// The first spelling met among the tracks.
  final String name;
  final int songCount;

  /// Albums holding at least one of the artist's tracks.
  final int albumCount;
}

/// Splits each `artist` value into names (guests included) and merges them
/// by key: a track counts once per name even if the name repeats in it, and
/// the albums of every value are united. Names only found as album artist
/// are not artists here.
List<ArtistSummary> buildArtistSummaries(List<ArtistCredit> credits) {
  final names = <String, String>{};
  final songs = <String, int>{};
  final albums = <String, Set<AlbumKey>>{};
  for (final credit in credits) {
    final display = splitArtists(credit.artist);
    final keys = splitArtists(credit.artistKey);
    // lower() keeps "; " in place, so both lists line up.
    if (display.length != keys.length) continue;
    final seen = <String>{};
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (!seen.add(key)) continue;
      names.putIfAbsent(key, () => display[i]);
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
