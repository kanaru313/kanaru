import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';

// Raw SQL checks of the constraints the schema promises. Feature code owns
// the real queries; these pin what the tables allow and refuse.

/// The lazy Favorites creation the invariants in `user_data_tables.dart`
/// prescribe: insert-or-ignore, then read the id, in one transaction.
Future<int> _favoritesId(LibraryDatabase db) => db.transaction(() async {
  await db
      .into(db.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: 'Favorites',
          createdAt: 1,
          kind: const Value('favorites'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  final row = await db
      .customSelect("SELECT id FROM playlists WHERE kind = 'favorites'")
      .getSingle();
  return row.read<int>('id');
});

Future<int> _count(LibraryDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
        .read<int>('n');

Future<void> _playlist(LibraryDatabase db, String name, String? kind) => db
    .into(db.playlists)
    .insert(
      PlaylistsCompanion.insert(name: name, createdAt: 1, kind: Value(kind)),
    );

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('playlist kinds', () {
    test('a second favorites row is refused', () async {
      await _playlist(db, 'Favorites', 'favorites');
      await expectLater(
        _playlist(db, 'Other', 'favorites'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('ordinary and queue rows may repeat', () async {
      for (final name in ['a', 'b', 'c']) {
        await _playlist(db, name, null);
      }
      await _playlist(db, 'q1', 'queue');
      await _playlist(db, 'q2', 'queue');
      expect(await _count(db, 'playlists'), 5);
    });

    test('favorites can be created again after it was deleted', () async {
      await _playlist(db, 'Favorites', 'favorites');
      await db.customStatement(
        "DELETE FROM playlists WHERE kind = 'favorites'",
      );
      await _playlist(db, 'Favorites', 'favorites');
      expect(await _count(db, 'playlists'), 1);
    });

    test('lazy creation twice gives one row and the same id', () async {
      await _playlist(db, 'Mix', null);
      final first = await _favoritesId(db);
      final second = await _favoritesId(db);
      expect(second, first);
      final rows = await db
          .customSelect("SELECT id FROM playlists WHERE kind = 'favorites'")
          .get();
      expect(rows, hasLength(1));
    });
  });

  group('cover_colors', () {
    Future<void> color(String key) => db
        .into(db.coverColors)
        .insert(
          CoverColorsCompanion.insert(
            coverKey: key,
            seed: 0xFF336699,
            palette: 'ff336699,ff112233',
            algoVersion: 1,
          ),
        );

    test('the cover key is the primary key', () async {
      await color('ab/c');
      await expectLater(color('ab/c'), throwsA(isA<SqliteException>()));
    });

    test('orphan cleanup needs IS NOT NULL', () async {
      final rootId = (await db.addRoots(['/m'], now: 1)).single;
      for (final (path, key) in [
        ('/m/a.flac', 'ab/kept'),
        ('/m/b.flac', null),
      ]) {
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                rootId: rootId,
                path: path,
                mtimeMs: 1,
                sizeBytes: 1,
                title: 'T',
                coverKey: Value(key),
                addedAt: 1,
                updatedAt: 1,
              ),
            );
      }
      await color('ab/kept');
      await color('ab/orphan');

      // A NULL in the subquery makes NOT IN NULL for every row.
      await db.customStatement(
        'DELETE FROM cover_colors WHERE cover_key NOT IN '
        '(SELECT cover_key FROM tracks)',
      );
      expect(await _count(db, 'cover_colors'), 2);

      await db.customStatement(
        'DELETE FROM cover_colors WHERE cover_key NOT IN '
        '(SELECT cover_key FROM tracks WHERE cover_key IS NOT NULL)',
      );
      final keys = await db.select(db.coverColors).get();
      expect(keys.map((c) => c.coverKey), ['ab/kept']);
    });
  });

  test('excluded folder paths are unique', () async {
    Future<void> exclude(String path) => db
        .into(db.excludedFolders)
        .insert(ExcludedFoldersCompanion.insert(path: path, addedAt: 1));
    await exclude('/m/podcasts');
    await expectLater(exclude('/m/podcasts'), throwsA(isA<SqliteException>()));
  });

  test('reset-library.sql clears scan data and keeps user data', () async {
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            rootId: rootId,
            path: '/m/a.flac',
            mtimeMs: 1,
            sizeBytes: 1,
            title: 'T',
            coverKey: const Value('ab/c'),
            addedAt: 1,
            updatedAt: 1,
          ),
        );
    await db.customStatement(
      "INSERT INTO plays (path, played_at) VALUES ('/m/a.flac', 1)",
    );
    final playlistId = await _favoritesId(db);
    await db.customStatement(
      'INSERT INTO playlist_entries (playlist_id, path, position) '
      "VALUES ($playlistId, '/m/a.flac', 0)",
    );
    await db.customStatement(
      "INSERT INTO cover_colors VALUES ('ab/c', 1, 'ff000000', 1)",
    );
    await db.customStatement(
      "INSERT INTO excluded_folders (path, added_at) VALUES ('/m/x', 1)",
    );

    // The script's statements without the sqlite3 shell's own lines
    // (PRAGMA and the transaction are set by the test database).
    final script = File('packaging/dev/reset-library.sql').readAsStringSync();
    final statements = script
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n')
        .split(';')
        .map((s) => s.trim())
        .where(
          (s) =>
              s.isNotEmpty &&
              !s.startsWith('PRAGMA') &&
              !s.startsWith('BEGIN') &&
              !s.startsWith('COMMIT'),
        );
    for (final statement in statements) {
      await db.customStatement(statement);
    }

    for (final table in ['library_roots', 'tracks', 'cover_colors']) {
      expect(await _count(db, table), 0, reason: table);
    }
    for (final table in [
      'plays',
      'play_stats',
      'playlists',
      'playlist_entries',
      'excluded_folders',
    ]) {
      expect(await _count(db, table), 1, reason: table);
    }
  });
}
