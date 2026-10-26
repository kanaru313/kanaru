import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_database.dart';
import 'library_startup.dart';

/// Which paths the library knows, for adding songs that came from outside a
/// library list (M3U lines, the play queue).
extension PlaylistLibraryPaths on LibraryDatabase {
  /// The paths of [paths] that have a row in `tracks`. Paths are compared as
  /// stored (invariant 1), so callers pass canonical paths.
  Future<Set<String>> libraryPathsAmong(Iterable<String> paths) async {
    final wanted = paths.toSet();
    if (wanted.isEmpty) return const {};
    // One JSON array instead of one variable per path: SQLite caps the
    // variables of a statement.
    final rows = await customSelect(
      'SELECT path FROM tracks WHERE path IN (SELECT value FROM json_each(?1))',
      variables: [Variable.withString(jsonEncode(wanted.toList()))],
      readsFrom: {tracks},
    ).get();
    return {for (final row in rows) row.read<String>('path')};
  }
}

/// Whether the song at the path is a row of the library, for rows drawn
/// outside a library list (the play queue). False without a library. Only
/// built for rows on screen. It does not follow rescans (the heart's press
/// re-checks the library); while it loads the value is null, and callers
/// pick their own meaning for that.
final isLibraryPathProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  path,
) async {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return false;
  return (await db.libraryPathsAmong([path])).contains(path);
});
