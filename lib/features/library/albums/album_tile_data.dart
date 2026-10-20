import '../../../core/database/library_database.dart';

/// What an album tile shows. No track count: on an artist page it is built
/// from that artist's tracks only, which may not be the whole album.
class AlbumTileData {
  const AlbumTileData({
    required this.key,
    required this.title,
    this.artist,
    this.year,
    this.coverKey,
  });

  AlbumTileData.fromSummary(AlbumSummary album)
    : this(
        key: album.key,
        title: album.title,
        artist: album.artist,
        year: album.year,
        coverKey: album.coverKey,
      );

  /// This tile with [coverKey] as its cover.
  AlbumTileData withCoverKey(String? coverKey) => AlbumTileData(
    key: key,
    title: title,
    artist: artist,
    year: year,
    coverKey: coverKey,
  );

  final AlbumKey key;
  final String title;
  final String? artist;
  final int? year;

  /// Cover key of the whole album (not only of some of its tracks).
  final String? coverKey;
}
