import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

/// The whole Songs list in one query: the reference the paged reads are
/// compared with, since it orders by `songsOrderSql` with no paging at all.
String songsSql(SongOrder order, {bool descending = false}) =>
    'SELECT $songColumns FROM tracks '
    'ORDER BY ${songsOrderSql(order, descending: descending)}';

extension SongsReferenceQuery on LibraryDatabase {
  /// Every track of the Songs list in [order].
  Future<List<TrackListItem>> songs({
    SongOrder order = SongOrder.title,
    bool descending = false,
  }) => customSelect(
    songsSql(order, descending: descending),
    readsFrom: {tracks},
  ).map(trackListItemFromRow).get();
}
