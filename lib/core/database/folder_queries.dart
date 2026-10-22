import 'package:drift/drift.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';

/// Paths read per statement by [FolderQueries.folderSongCounts]: each
/// statement stays short and the counting between pages is a small slice of
/// work on the UI isolate. The caller's transaction still holds the database
/// for the whole read (about 0.25 s on 100k tracks).
const _pathPageSize = 5000;

/// Queries for browsing the library by folder. There is no folder table: a
/// folder is a prefix of `tracks.path`, so nothing here touches the disk.
/// They run once per call; a screen that follows `tracks` wraps them in
/// `throttledTracksQuery`.
extension FolderQueries on LibraryDatabase {
  /// Every folder holding at least one track directly, with how many it holds
  /// (not counting its subfolders). `dir` is the absolute path without a
  /// trailing `/`.
  ///
  /// Reads the paths in pages ordered by path (the unique index, no sorting)
  /// and takes the directory of each in Dart: grouping by a directory
  /// expression in SQL (`rtrim(path, replace(path, '/', ''))`) holds the
  /// database isolate for seconds on 100k tracks.
  Future<List<({String dir, int count})>> folderSongCounts({
    int pageSize = _pathPageSize,
  }) async {
    final counts = <String, int>{};
    var after = '';
    while (true) {
      final paths = await customSelect(
        'SELECT path FROM tracks WHERE path > ?1 ORDER BY path LIMIT ?2',
        variables: [Variable(after), Variable(pageSize)],
        readsFrom: {tracks},
      ).map((row) => row.read<String>('path')).get();
      for (final path in paths) {
        final slash = path.lastIndexOf('/');
        counts.update(
          slash < 0 ? '' : path.substring(0, slash),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
      if (paths.length < pageSize) break;
      after = paths.last;
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        (dir: key, count: value),
    ];
  }

  /// The tracks under [dir] (no trailing `/`): only the ones directly in it,
  /// or with [recursive] those of all its subfolders too. In database order
  /// (by path, BINARY); a screen puts them in natural order.
  ///
  /// The range is every path starting with `dir/`: `0` is the character after
  /// `/`, so under BINARY collation `path >= 'dir/' AND path < 'dir0'` holds
  /// exactly those, and uses the unique index of `path`.
  Future<List<TrackListItem>> folderTracks(
    String dir, {
    required bool recursive,
  }) => customSelect(
    'SELECT $songColumns FROM tracks WHERE path >= ?1 AND path < ?2'
    '${recursive ? '' : " AND instr(substr(path, length(?1) + 1), '/') = 0"}'
    ' ORDER BY path',
    variables: [Variable('$dir/'), Variable('${dir}0')],
    readsFrom: {tracks},
  ).map(trackListItemFromRow).get();
}
