import 'package:drift/drift.dart';

import 'library_database.dart';

/// Queries behind the scan's length filter.
extension ScanFilterQueries on LibraryDatabase {
  /// Ids of the tracks of root [rootId] known to be shorter than
  /// [minDurationMs]. A track without a duration is never short; a
  /// [minDurationMs] of 0 or less matches nothing.
  Future<List<int>> shortTrackIds(int rootId, int minDurationMs) async {
    if (minDurationMs <= 0) return const [];
    final query = selectOnly(tracks)
      ..addColumns([tracks.id])
      ..where(
        tracks.rootId.equals(rootId) &
            tracks.durationMs.isSmallerThanValue(minDurationMs),
      );
    return [for (final row in await query.get()) row.read(tracks.id)!];
  }
}
