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
  /// (not counting its subfolders) and its cover: the cover key held by the
  /// most of those tracks (the smallest key on a tie), `null` when none has
  /// one. `dir` is the absolute path without a trailing `/`.
  ///
  /// Reads the paths in pages ordered by path (the unique index, no sorting)
  /// and takes the directory of each in Dart: grouping by a directory
  /// expression in SQL (`rtrim(path, replace(path, '/', ''))`) holds the
  /// database isolate for seconds on 100k tracks. The cover is chosen after the
  /// last page, so it does not depend on the page size.
  Future<List<({String dir, int count, String? cover})>> folderSongCounts({
    int pageSize = _pathPageSize,
  }) async {
    final dirs = <String, _DirCovers>{};
    var after = '';
    while (true) {
      final rows = await customSelect(
        'SELECT path, cover_key FROM tracks '
        'WHERE path > ?1 ORDER BY path LIMIT ?2',
        variables: [Variable(after), Variable(pageSize)],
        readsFrom: {tracks},
      ).get();
      // `data` skips the typed read of every column: the columns are known.
      for (final row in rows) {
        final path = row.data['path']! as String;
        final slash = path.lastIndexOf('/');
        final acc = dirs.putIfAbsent(
          slash < 0 ? '' : path.substring(0, slash),
          _DirCovers.new,
        );
        acc.count++;
        final cover = row.data['cover_key'] as String?;
        if (cover != null) acc.add(cover);
      }
      if (rows.length < pageSize) break;
      after = rows.last.data['path']! as String;
    }
    return [
      for (final MapEntry(:key, :value) in dirs.entries)
        (dir: key, count: value.count, cover: value.top()),
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

/// What [FolderQueries.folderSongCounts] holds for one folder: its track count
/// and how many tracks carry each cover key. The first key sits in fields and
/// the map is only made for a second distinct key, which saves an allocation
/// for folders with a single cover.
class _DirCovers {
  int count = 0;
  String? _first;
  int _firstCount = 0;
  Map<String, int>? _others;

  void add(String key) {
    if (_first == null || key == _first) {
      _first = key;
      _firstCount++;
    } else {
      (_others ??= {}).update(key, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  /// The key held by the most tracks; the smallest key on a tie.
  String? top() {
    var best = _first;
    var bestCount = _firstCount;
    for (final MapEntry(:key, :value) in _others?.entries ?? const []) {
      if (value > bestCount ||
          (value == bestCount && key.compareTo(best!) < 0)) {
        best = key;
        bestCount = value;
      }
    }
    return best;
  }
}
