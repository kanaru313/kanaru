import '../../../core/database/artist_names.dart';
import '../../../core/database/library_database.dart';
import '../albums/album_header.dart' show AlbumInfo;
import '../albums/album_tile_data.dart';
import '../sort_compare.dart';

/// What an artist page lists, from the tracks crediting the artist:
/// - [albums]: albums whose album artist (else first track artist) is them,
/// - [songs]: every one of those tracks, in query order,
/// - [appearsOn]: the other albums those tracks belong to.
class ArtistPageSections {
  const ArtistPageSections({
    required this.name,
    required this.albums,
    required this.songs,
    required this.appearsOn,
  });

  factory ArtistPageSections.fromTracks(String key, List<BrowseTrack> tracks) {
    final byAlbum = <AlbumKey, List<BrowseTrack>>{};
    for (final track in tracks) {
      final albumKey = track.albumKey;
      if (albumKey != null) (byAlbum[albumKey] ??= []).add(track);
    }
    final albums = <AlbumTileData>[];
    final appearsOn = <AlbumTileData>[];
    for (final MapEntry(key: albumKey, value: albumTracks) in byAlbum.entries) {
      final tile = _tileData(albumKey, albumTracks);
      (splitArtists(albumKey.artistKey).contains(key) ? albums : appearsOn).add(
        tile,
      );
    }
    albums.sort(_byYearThenTitle);
    appearsOn.sort(_byYearThenTitle);
    return ArtistPageSections(
      name: _displayName(key, tracks) ?? key,
      albums: albums,
      songs: tracks,
      appearsOn: appearsOn,
    );
  }

  /// The spelling of the first track that credits the artist.
  final String name;
  final List<AlbumTileData> albums;
  final List<BrowseTrack> songs;
  final List<AlbumTileData> appearsOn;

  /// Albums on the page, both sections.
  int get albumCount => albums.length + appearsOn.length;
}

/// The spelling of [key] in the first track that credits it.
String? _displayName(String key, List<BrowseTrack> tracks) {
  for (final track in tracks) {
    for (final name in splitArtists(track.artist)) {
      if (artistKey(name) == key) return name;
    }
  }
  return null;
}

/// Album details from the tracks at hand (only this artist's, so the tile
/// shows no track count).
AlbumTileData _tileData(AlbumKey key, List<BrowseTrack> tracks) {
  final info = AlbumInfo.fromTracks(tracks);
  return AlbumTileData(
    key: key,
    title: info.title,
    artist: info.artist,
    year: info.year,
  );
}

/// Year ascending (unknown last), then title ignoring case.
int _byYearThenTitle(AlbumTileData a, AlbumTileData b) {
  final year = compareNullsLast(a.year, b.year);
  return year != 0 ? year : compareText(a.title, b.title);
}
