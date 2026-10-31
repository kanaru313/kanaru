import 'package:drift/drift.dart';

import 'artist_names.dart';
import 'library_database.dart';

/// Where a song's menu can go: its credited artists (tag order), album and
/// album artists.
class TrackLinks {
  const TrackLinks({
    required this.artists,
    required this.album,
    this.albumArtists = const [],
  });

  final List<({String key, String name})> artists;

  /// The artists of the `album_artist` tag (tag order) that have an artist
  /// page, i.e. credit at least one track. A name found only as album artist
  /// has no page and is left out, as on the album page.
  final List<({String key, String name})> albumArtists;

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
      'SELECT artist IS NOT NULL AS has_artist, album_artist AS aa, '
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
    final albumArtists = <({String key, String name})>[];
    for (final name in splitArtists(row.readNullable<String>('aa'))) {
      final key = artistKey(name);
      final page = await customSelect(
        'SELECT 1 FROM track_artists WHERE artist_key = ?1 LIMIT 1',
        variables: [Variable(key)],
        readsFrom: {trackArtists},
      ).get();
      if (page.isNotEmpty) albumArtists.add((key: key, name: name));
    }
    return TrackLinks(
      albumArtists: albumArtists,
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

  /// What the song menu needs of the track at [path]: its id and whether it
  /// has an artist and an album to link to. Null when [path] is not a row of
  /// the library (a file opened from outside it). Read from the row, never
  /// from a snapshot of the track, which an old saved queue lacks fields of.
  /// An empty artist counts as no artist, as `SongTile` treats it.
  Future<({int id, bool hasArtist, bool hasAlbum})?> trackMenuStateOfPath(
    String path,
  ) async {
    final row = await customSelect(
      "SELECT id, artist IS NOT NULL AND artist <> '' AS has_artist, "
      'album_title_key IS NOT NULL AS has_album '
      'FROM tracks WHERE path = ?1',
      variables: [Variable(path)],
      readsFrom: {tracks},
    ).getSingleOrNull();
    if (row == null) return null;
    return (
      id: row.read<int>('id'),
      hasArtist: row.read<bool>('has_artist'),
      hasAlbum: row.read<bool>('has_album'),
    );
  }
}
