import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'library_browse_queries.dart';
import 'library_database.dart';
import 'library_startup.dart';

final _log = Logger('library.trackOfPath');

/// The library row of the song at a path, for rows drawn outside a library
/// list (the play queue) that need its id and cover at gesture time.
extension LibraryTrackOfPath on LibraryDatabase {
  /// The row of [path] as stored (callers pass canonical paths), or null when
  /// the library has no such row.
  Future<TrackListItem?> libraryTrackOfPath(String path) async {
    final row = await customSelect(
      'SELECT $songColumns FROM tracks WHERE path = ?1',
      variables: [Variable.withString(path)],
      readsFrom: {tracks},
    ).getSingleOrNull();
    return row == null ? null : trackListItemFromRow(row);
  }
}

/// The library row of the song at the path, or null without a library or when
/// the path is not a row of it. It follows the library: a rescan that drops or
/// changes the row updates it. A read error is logged and also gives null, so
/// callers fall back to their plain behavior. It is only built for rows on
/// screen; while it loads the value is null.
final libraryTrackOfPathProvider = StreamProvider.autoDispose
    .family<TrackListItem?, String>((ref, path) async* {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) {
        yield null;
        return;
      }
      try {
        final rows = db
            .customSelect(
              'SELECT $songColumns FROM tracks WHERE path = ?1',
              variables: [Variable.withString(path)],
              readsFrom: {db.tracks},
            )
            .watchSingleOrNull();
        await for (final row in rows) {
          yield row == null ? null : trackListItemFromRow(row);
        }
      } catch (e, s) {
        _log.warning('Reading the library row of a path failed', e, s);
        yield null;
      }
    });
