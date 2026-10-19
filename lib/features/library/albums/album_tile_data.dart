import '../../../core/database/library_database.dart';

/// What an album tile shows. No track count: on an artist page it is built
/// from that artist's tracks only, which may not be the whole album.
class AlbumTileData {
  const AlbumTileData({
    required this.key,
    required this.title,
    this.artist,
    this.year,
  });

  AlbumTileData.fromSummary(AlbumSummary album)
    : this(
        key: album.key,
        title: album.title,
        artist: album.artist,
        year: album.year,
      );

  final AlbumKey key;
  final String title;
  final String? artist;
  final int? year;
}
