import 'package:drift/drift.dart';

import 'library_database.dart';

/// The folders the user left out of the library scan. Paths are canonical;
/// matching against them is done in Dart with `isSameOrInside`, never in SQL
/// (`LIKE` treats `%` and `_` in folder names as wildcards).
extension ExcludedFolderQueries on LibraryDatabase {
  /// All exclusions ordered by path; emits again on every write to the table.
  Stream<List<ExcludedFolder>> watchExcludedFolders() => (select(
    excludedFolders,
  )..orderBy([(e) => OrderingTerm.asc(e.path)])).watch();

  /// The paths of all exclusions; read at the start of every scan.
  Future<List<String>> excludedFolderPaths() async {
    final query = selectOnly(excludedFolders)
      ..addColumns([excludedFolders.path]);
    return [
      for (final row in await query.get()) row.read(excludedFolders.path)!,
    ];
  }

  /// Stores [canonicalPath]; `false` when it is already excluded.
  Future<bool> addExcludedFolder(String canonicalPath, int now) async {
    // The row count tells a write from an ignored duplicate; the id that
    // `insertOrIgnore` returns does not.
    final written = await customUpdate(
      'INSERT OR IGNORE INTO excluded_folders (path, added_at) VALUES (?, ?)',
      variables: [Variable.withString(canonicalPath), Variable.withInt(now)],
      updates: {excludedFolders},
    );
    return written > 0;
  }

  /// Deletes exclusion [id]; nothing happens when it is already gone.
  Future<void> removeExcludedFolder(int id) =>
      (delete(excludedFolders)..where((e) => e.id.equals(id))).go();
}
