import '../../core/database/library_browse_queries.dart';
import '../../core/database/library_database.dart' show LibraryDatabase;
import 'artist_page_sections.dart';

/// Reads the page of one artist (by key): tracks and album rows in one
/// transaction, arranged into sections. Null when no track credits the artist.
Future<ArtistPageSections?> readArtistSections(
  LibraryDatabase db,
  String artistKey,
) => db.transaction(() async {
  final (tracks, albums) = await (
    db.artistTracks(artistKey),
    db.artistAlbums(artistKey),
  ).wait;
  return tracks.isEmpty
      ? null
      : ArtistPageSections.fromTracks(artistKey, tracks, albums);
});
