import '../../../core/database/library_database.dart';

/// What an album tile shows. No track count: the artist page lists albums
/// the artist is only part of.
class AlbumTileData {
  const AlbumTileData({
    required this.key,
    required this.title,
    this.artist,
    this.year,
    this.coverKey,
    this.variousArtists = false,
  });

  AlbumTileData.fromSummary(AlbumSummary album)
    : this(
        key: album.key,
        title: album.title,
        artist: album.artist,
        year: album.year,
        coverKey: album.coverKey,
        variousArtists: album.variousArtists,
      );

  final AlbumKey key;
  final String title;
  final String? artist;
  final int? year;

  /// Cover key of the whole album.
  final String? coverKey;

  /// Several album artists merged into the album; [artist] is one of them.
  final bool variousArtists;
}
