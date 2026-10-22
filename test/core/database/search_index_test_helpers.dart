import 'package:drift/drift.dart';
import 'package:kanaru/core/database/library_database.dart';

/// Fails when `track_search` disagrees with itself or with `tracks`, the
/// content table (FTS5 `integrity-check` with rank 1 compares the two).
Future<void> expectSearchIndexIntact(LibraryDatabase db) => db.customStatement(
  "INSERT INTO track_search(track_search, rank) VALUES ('integrity-check', 1)",
);

/// Ids of the tracks `track_search` returns for the FTS5 query [fts], in id
/// order.
Future<List<int>> idsMatching(LibraryDatabase db, String fts) async => [
  for (final row
      in await db
          .customSelect(
            'SELECT rowid FROM track_search WHERE track_search MATCH ?1 '
            'ORDER BY rowid',
            variables: [Variable.withString(fts)],
          )
          .get())
    row.read<int>('rowid'),
];
