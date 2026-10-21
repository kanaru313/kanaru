import 'package:drift/drift.dart';

import 'library_database.dart';

/// Library root removal and replacement. `tracks.root_id` and
/// `track_artists.track_id` cascade on delete, and albums and artists are
/// derived from `tracks`, so deleting one root row removes everything under
/// it in one statement.
extension LibraryRootQueries on LibraryDatabase {
  /// All roots, ordered by id; emits again on every write to `library_roots`
  /// (add, remove, scan stamp), not on track writes.
  Stream<List<LibraryRoot>> watchRoots() =>
      (select(libraryRoots)..orderBy([(r) => OrderingTerm.asc(r.id)])).watch();

  Future<bool> rootExists(int id) async {
    final row =
        await (selectOnly(libraryRoots)
              ..addColumns([libraryRoots.id])
              ..where(libraryRoots.id.equals(id)))
            .getSingleOrNull();
    return row != null;
  }

  /// Number of tracks stored under root [id] (indexed on `tracks.root_id`).
  Future<int> trackCountOfRoot(int id) async {
    final count = tracks.id.count();
    final row =
        await (selectOnly(tracks)
              ..addColumns([count])
              ..where(tracks.rootId.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Deletes root [id] and, by cascade, its tracks and artist links. Does
  /// nothing when the root is already gone.
  Future<void> removeRoot(int id) =>
      (delete(libraryRoots)..where((r) => r.id.equals(id))).go();

  /// Removes root [id] and adds [path] as a new root in one transaction, and
  /// returns the new id. When anything fails (for example [path] is already
  /// a root) nothing changes and the error is rethrown.
  Future<int> replaceRoot(int id, String path, {required int now}) {
    return transaction(() async {
      await removeRoot(id);
      return into(libraryRoots)
          .insert(LibraryRootsCompanion.insert(path: path, addedAt: now));
    });
  }
}
