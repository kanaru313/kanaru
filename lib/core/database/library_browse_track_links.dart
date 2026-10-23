import 'package:drift/drift.dart';

import 'library_database.dart';

/// Where a song's menu can go: its credited artists (tag order) and album.
class TrackLinks {
  const TrackLinks({required this.artists, required this.album});

  final List<({String key, String name})> artists;

  /// Null when the track has no album title.
  final AlbumKey? album;
}

extension LibraryBrowseTrackLinks on LibraryDatabase {
  /// The artists and album a track links to; null when the row is gone (a
  /// rescan removed it). Artists are the `track_artists` rows of the track in
  /// the order they were written (the order of the tag), so the links follow
  /// whatever split rules keyed the track and need none here; the album key
  /// follows the rule of the album page.
  Future<TrackLinks?> trackLinks(int id) async {
    final row = await customSelect(
      'SELECT artist IS NOT NULL AS has_artist, '
      'album_artist_key AS ak, album_title_key AS tk '
      'FROM tracks WHERE id = ?1',
      variables: [Variable(id)],
      readsFrom: {tracks},
    ).getSingleOrNull();
    if (row == null) return null;
    // A tag cleared in the row is no artist even before the credits catch up.
    final credits = row.read<bool>('has_artist')
        ? await customSelect(
            'SELECT artist_key, artist_name FROM track_artists '
            'WHERE track_id = ?1 ORDER BY rowid',
            variables: [Variable(id)],
            readsFrom: {trackArtists},
          ).get()
        : const <QueryRow>[];
    final titleKey = row.readNullable<String>('tk');
    return TrackLinks(
      artists: [
        for (final credit in credits)
          (
            key: credit.read<String>('artist_key'),
            name: credit.read<String>('artist_name'),
          ),
      ],
      album: titleKey == null
          ? null
          : AlbumKey(row.read<String>('ak'), titleKey),
    );
  }
}
