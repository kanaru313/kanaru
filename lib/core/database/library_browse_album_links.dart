import 'package:drift/drift.dart';

import 'artist_names.dart';
import 'library_browse_queries.dart';
import 'library_database.dart';

/// One folder holding tracks of an album.
class AlbumFolder {
  const AlbumFolder({
    required this.path,
    required this.songCount,
    required this.samplePath,
  });

  /// The directory, without a trailing `/` (a file in the root gives `/`).
  final String path;
  final int songCount;

  /// The smallest track path in the folder; what Show in file manager opens.
  final String samplePath;

  @override
  bool operator ==(Object other) =>
      other is AlbumFolder &&
      other.path == path &&
      other.songCount == songCount &&
      other.samplePath == samplePath;

  @override
  int get hashCode => Object.hash(path, songCount, samplePath);

  @override
  String toString() => 'AlbumFolder($path, $songCount, $samplePath)';
}

/// What the album modal links to: the album itself, its artists and the
/// folders its tracks are in.
class AlbumLinks {
  const AlbumLinks({
    required this.summary,
    required this.artists,
    required this.folders,
  });

  final AlbumSummary summary;

  /// The album artists of the tags that credit a track of this album: in
  /// tag order, and for a merged album in the order of the first track id
  /// per `album_artist` value. When none, the artists credited on the
  /// album's tracks, most tracks first, ties in credit write order.
  final List<({String key, String name})> artists;

  /// Local folders, most songs first, then by path.
  final List<AlbumFolder> folders;
}

/// Groups track [paths] by directory. Paths with a scheme (`://`) or without
/// a directory are not local files and are left out.
List<AlbumFolder> albumFoldersOf(Iterable<String> paths) {
  final counts = <String, int>{};
  final samples = <String, String>{};
  for (final path in paths) {
    final cut = path.lastIndexOf('/');
    if (path.contains('://') || cut < 0) continue;
    final dir = cut == 0 ? '/' : path.substring(0, cut);
    counts[dir] = (counts[dir] ?? 0) + 1;
    final sample = samples[dir];
    if (sample == null || path.compareTo(sample) < 0) samples[dir] = path;
  }
  final folders = [
    for (final e in counts.entries)
      AlbumFolder(path: e.key, songCount: e.value, samplePath: samples[e.key]!),
  ];
  folders.sort((a, b) {
    final byCount = b.songCount.compareTo(a.songCount);
    return byCount != 0 ? byCount : a.path.compareTo(b.path);
  });
  return folders;
}

/// Album artists, in tag order (`?1`, `?2`: the album key).
const albumArtistNamesSql =
    'SELECT album_artist AS aa FROM tracks '
    'WHERE album_artist_key = ?1 AND album_title_key = ?2 '
    'AND album_artist IS NOT NULL '
    'GROUP BY album_artist ORDER BY min(id)';

/// Which of the keys `?3...` are credited on a track of the album (`?1`,
/// `?2`: the album key); the placeholders follow the keys.
String albumCreditedKeysSql(int count) =>
    'SELECT DISTINCT ta.artist_key AS artist_key '
    'FROM tracks AS t JOIN track_artists AS ta ON ta.track_id = t.id '
    'WHERE t.album_artist_key = ?1 AND t.album_title_key = ?2 '
    'AND ta.artist_key IN (${List.filled(count, '?').join(', ')})';

/// Track artists of the album, most tracks first (`?1`, `?2`: the album key).
const albumTrackArtistsSql =
    'SELECT ta.artist_key AS k, min(ta.artist_name) AS name '
    'FROM tracks AS t JOIN track_artists AS ta ON ta.track_id = t.id '
    'WHERE t.album_artist_key = ?1 AND t.album_title_key = ?2 '
    'GROUP BY ta.artist_key '
    'ORDER BY count(*) DESC, min(ta.rowid)';

/// Track paths of the album (`?1`, `?2`: the album key).
const albumPathsSql =
    'SELECT path FROM tracks '
    'WHERE album_artist_key = ?1 AND album_title_key = ?2';

extension LibraryBrowseAlbumLinks on LibraryDatabase {
  /// The artists and folders of an album; null when it has no tracks (a
  /// rescan removed them). One transaction, so the parts agree.
  ///
  /// Artists: the names of the `album_artist` tag (split with the default
  /// rules, as `trackLinks` does) that are credited on a track of this album,
  /// not elsewhere in the library, so a stray credit of "Various Artists"
  /// on another album cannot hide the real artists of a compilation. When
  /// none, the artists credited on the album's tracks.
  Future<AlbumLinks?> albumLinks(AlbumKey key) => transaction(() async {
    final summary = await album(key);
    if (summary == null) return null;
    final vars = [Variable(key.artistKey), Variable(key.titleKey)];

    final names = <String, String>{};
    final tags = await customSelect(
      albumArtistNamesSql,
      variables: vars,
      readsFrom: {tracks},
    ).get();
    for (final row in tags) {
      for (final name in splitArtists(row.read<String>('aa'))) {
        names.putIfAbsent(artistKey(name), () => name);
      }
    }
    var artists = <({String key, String name})>[];
    if (names.isNotEmpty) {
      final keys = names.keys.toList();
      final withPage = {
        for (final r in await customSelect(
          albumCreditedKeysSql(keys.length),
          variables: [...vars, for (final k in keys) Variable(k)],
          readsFrom: {tracks, trackArtists},
        ).get())
          r.read<String>('artist_key'),
      };
      artists = [
        for (final e in names.entries)
          if (withPage.contains(e.key)) (key: e.key, name: e.value),
      ];
    }
    if (artists.isEmpty) {
      artists = [
        for (final r in await customSelect(
          albumTrackArtistsSql,
          variables: vars,
          readsFrom: {tracks, trackArtists},
        ).get())
          (key: r.read<String>('k'), name: r.read<String>('name')),
      ];
    }

    final paths = await customSelect(
      albumPathsSql,
      variables: vars,
      readsFrom: {tracks},
    ).get();
    return AlbumLinks(
      summary: summary,
      artists: artists,
      folders: albumFoldersOf([for (final r in paths) r.read<String>('path')]),
    );
  });
}
