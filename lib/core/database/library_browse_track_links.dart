import 'package:drift/drift.dart';

import 'artist_names.dart';
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
  /// rescan removed it). Artists come from the `artist` tag split the way
  /// `track_artists` was filled, so no join is needed; the album key follows
  /// the rule of the album page.
  Future<TrackLinks?> trackLinks(int id) async {
    final row = await customSelect(
      'SELECT artist, album_artist_key AS ak, album_title_key AS tk '
      'FROM tracks WHERE id = ?1',
      variables: [Variable(id)],
      readsFrom: {tracks},
    ).getSingleOrNull();
    if (row == null) return null;
    final titleKey = row.readNullable<String>('tk');
    return TrackLinks(
      artists: [
        for (final name in splitArtists(row.readNullable<String>('artist')))
          (key: artistKey(name), name: name),
      ],
      album: titleKey == null
          ? null
          : AlbumKey(row.read<String>('ak'), titleKey),
    );
  }
}
