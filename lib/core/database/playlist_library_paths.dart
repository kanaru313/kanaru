import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';

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
