import '../../../core/database/artist_names.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/text_keys.dart';
import '../albums/album_tile_data.dart';
import '../sort_compare.dart';
import 'artist_summaries.dart' show preferredSpelling;

/// What an artist page lists:
/// - [albums]: albums the artist owns (one of its album artists, else its
///   first track artist),
/// - [songs]: every track crediting the artist, in the order of the album
///   tiles (the albums, then those appeared on), each album as the
///   query orders it (disc, track, title), tracks without an album last,
/// - [appearsOn]: the other albums holding those tracks.
///
/// Album details are the rows of the albums query, so a tile shows what the
/// Albums list shows; both sections order by year (unknown last), then by
/// the title sort key, then by album key.
class ArtistPageSections {
  const ArtistPageSections({
    required this.name,
    required this.albums,
    required this.songs,
    required this.appearsOn,
  });

  factory ArtistPageSections.fromTracks(
    String key,
    List<BrowseTrack> tracks,
    List<AlbumSummary> albumRows,
  ) {
    final owned = <AlbumSummary>[];
    final other = <AlbumSummary>[];
    for (final album in albumRows) {
      (album.key.artistKeys.contains(key) ? owned : other).add(album);
    }
    owned.sort(_byYearThenTitle);
    other.sort(_byYearThenTitle);
    return ArtistPageSections(
      name: _displayName(key, tracks) ?? key,
      albums: [for (final a in owned) AlbumTileData.fromSummary(a)],
      songs: _inTileOrder(tracks, [...owned, ...other]),
      appearsOn: [for (final a in other) AlbumTileData.fromSummary(a)],
    );
  }

  /// The artist's name, chosen by [preferredSpelling] like in the list.
  final String name;
  final List<AlbumTileData> albums;
  final List<BrowseTrack> songs;
  final List<AlbumTileData> appearsOn;

  /// Albums on the page, both sections.
  int get albumCount => albums.length + appearsOn.length;
}

/// The preferred spelling of [key] among the tracks that credit it.
String? _displayName(String key, List<BrowseTrack> tracks) {
  String? best;
  for (final track in tracks) {
    for (final name in splitArtists(track.artist)) {
      if (artistKey(name) == key) best = preferredSpelling(best, name);
    }
  }
  return best;
}

/// Year ascending (unknown last), then the title sort key, then the key.
int _byYearThenTitle(AlbumSummary a, AlbumSummary b) {
  final year = compareNullsLast(a.year, b.year);
  if (year != 0) return year;
  final title = (a.titleSort ?? artistSortKey(a.title)).compareTo(
    b.titleSort ?? artistSortKey(b.title),
  );
  if (title != 0) return title;
  final artist = a.key.artistKey.compareTo(b.key.artistKey);
  return artist != 0 ? artist : a.key.titleKey.compareTo(b.key.titleKey);
}

/// [tracks] (already ordered by album key, disc, track, title and id, as
/// the query returns them) grouped by the position of their album in
/// [albums]; tracks whose album is not in [albums], or that have none, go
/// last. One pass, each group keeps the query order.
List<BrowseTrack> _inTileOrder(
  List<BrowseTrack> tracks,
  List<AlbumSummary> albums,
) {
  final position = {for (final (i, a) in albums.indexed) a.key: i};
  final buckets = List.generate(albums.length + 1, (_) => <BrowseTrack>[]);
  for (final track in tracks) {
    buckets[position[track.albumKey] ?? albums.length].add(track);
  }
  return [for (final bucket in buckets) ...bucket];
}
