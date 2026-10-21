import 'package:drift/drift.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';

/// Rows per `songsByIds` query: what one screen of the Songs list shows.
const songPageSize = 200;

/// Rows per query while a play queue is read.
const _queueChunkSize = 2000;

/// The Songs list in pages: the ids in sort order are cheap to read, the rows
/// are read for the ids on screen. Orders match [LibraryBrowseQueries.songs].
extension LibrarySongPaging on LibraryDatabase {
  /// The ids of every track in the order of `songs(order, descending)`.
  /// Read as one concatenated value: building a result row per track costs
  /// more in Dart than the query does.
  Future<List<int>> songIds({
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) async {
    final row = await customSelect(
      'SELECT group_concat(id) AS ids FROM ('
      'SELECT id FROM tracks '
      'ORDER BY ${songsOrderSql(order, descending: descending)})',
      readsFrom: {tracks},
    ).getSingle();
    final ids = row.readNullable<String>('ids');
    if (ids == null) return const [];
    return [for (final id in ids.split(',')) int.parse(id)];
  }

  /// The first [limit] rows in the order of `songs(order, descending)`.
  Future<List<TrackListItem>> songsPage({
    SongOrder order = SongOrder.title,
    bool descending = false,
    int limit = songPageSize,
  }) => customSelect(
    'SELECT $songColumns FROM tracks '
    'ORDER BY ${songsOrderSql(order, descending: descending)} LIMIT ?',
    variables: [Variable.withInt(limit)],
    readsFrom: {tracks},
  ).map(trackListItemFromRow).get();

  /// The rows of [ids], in the order of [ids]. Ids without a track are
  /// dropped. Reads [songPageSize] ids per query.
  Future<List<TrackListItem>> songsByIds(List<int> ids) =>
      _songsByIds(ids, songPageSize);

  /// The whole Songs list in [order] and the index of [trackId] in it, from
  /// one read transaction so the index belongs to the returned list. The
  /// index is null when the track is gone.
  Future<(List<TrackListItem>, int?)> songQueueFrom(
    int trackId, {
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) => transaction(() async {
    final ids = await songIds(order: order, descending: descending);
    final items = await _songsByIds(ids, _queueChunkSize);
    final start = items.indexWhere((t) => t.id == trackId);
    return (items, start < 0 ? null : start);
  });

  Future<List<TrackListItem>> _songsByIds(List<int> ids, int chunk) async {
    final byId = <int, TrackListItem>{};
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(
        i,
        i + chunk < ids.length ? i + chunk : ids.length,
      );
      final marks = List.filled(part.length, '?').join(',');
      final rows = await customSelect(
        'SELECT $songColumns FROM tracks WHERE id IN ($marks)',
        variables: [for (final id in part) Variable.withInt(id)],
        readsFrom: {tracks},
      ).map(trackListItemFromRow).get();
      for (final item in rows) {
        byId[item.id] = item;
      }
    }
    return [for (final id in ids) ?byId[id]];
  }
}
