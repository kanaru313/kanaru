import 'package:drift/drift.dart' show Variable;

import 'library_database.dart';

/// What the stored tracks say about the scan: [tracks] stored, [tagErrors]
/// of them stored without tags (reading them failed), [withCover] having a
/// cover, and [covers] distinct thumbnails among those (tracks of one
/// image share a thumbnail, keyed by its hash).
typedef ScanDbStats = ({int tracks, int tagErrors, int withCover, int covers});

const _scanStatsSql = '''
SELECT
  count(*) AS tracks,
  count(scan_error) AS tag_errors,
  count(cover_key) AS with_cover,
  count(DISTINCT cover_key) AS covers
FROM tracks''';

extension ScanStatsQueries on LibraryDatabase {
  /// One pass over `tracks`; a screen that follows the library wraps this
  /// in `throttledTracksQuery`. `count(column)` skips NULLs, as wanted.
  Future<ScanDbStats> scanDbStats() =>
      customSelect(_scanStatsSql, readsFrom: {tracks})
          .map(
            (row) => (
              tracks: row.read<int>('tracks'),
              tagErrors: row.read<int>('tag_errors'),
              withCover: row.read<int>('with_cover'),
              covers: row.read<int>('covers'),
            ),
          )
          .getSingle();

  /// Tracks stored under the roots [rootIds] (0 for none).
  Future<int> storedTrackCount(List<int> rootIds) async {
    if (rootIds.isEmpty) return 0;
    final marks = List.filled(rootIds.length, '?').join(',');
    final row = await customSelect(
      'SELECT count(*) AS n FROM tracks WHERE root_id IN ($marks)',
      variables: [for (final id in rootIds) Variable.withInt(id)],
    ).getSingle();
    return row.read<int>('n');
  }
}
