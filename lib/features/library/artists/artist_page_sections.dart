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

  factory ArtistPageSections.fromTracks(
    String artistKey,
    List<BrowseTrack> tracks,
  ) {
    final byAlbum = <AlbumKey, List<BrowseTrack>>{};
    for (final track in tracks) {
      final key = track.albumKey;
      if (key != null) (byAlbum[key] ??= []).add(track);
    }
    final albums = <AlbumTileData>[];
    final appearsOn = <AlbumTileData>[];
    for (final MapEntry(:key, value: albumTracks) in byAlbum.entries) {
      final tile = _tileData(key, albumTracks);
      (splitArtists(key.artistKey).contains(artistKey) ? albums : appearsOn)
          .add(tile);
    }
    albums.sort(_byYearThenTitle);
    appearsOn.sort(_byYearThenTitle);
    return ArtistPageSections(
      name: _displayName(artistKey, tracks) ?? artistKey,
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

/// The name at the position of [artistKey] in the first track's artists:
/// `artist` and its lower-cased form split the same way.
String? _displayName(String artistKey, List<BrowseTrack> tracks) {
  for (final track in tracks) {
    final keys = splitArtists(track.artistKeys);
    final names = splitArtists(track.artist);
    final i = keys.indexOf(artistKey);
    if (i >= 0 && i < names.length) return names[i];
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
