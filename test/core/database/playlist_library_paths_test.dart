import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_library_paths.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;
  late int root;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    root = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  test('returns the paths that have a library track', () async {
    await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);

    expect(await db.libraryPathsAmong(['/m/a', '/m/x', '/m/b', '/m/a']), {
      '/m/a',
      '/m/b',
    });
  });

  test('is empty for no paths', () async {
    expect(await db.libraryPathsAmong(const []), isEmpty);
  });

  test('handles more paths than SQLite allows as variables', () async {
    final paths = [for (var i = 0; i < 2000; i++) '/m/$i'];
    await db.upsertTracks([track(root, '/m/7'), track(root, '/m/1999')]);

    expect(await db.libraryPathsAmong(paths), {'/m/7', '/m/1999'});
  });

  group('isLibraryPathProvider', () {
    ProviderContainer containerWith(LibraryDatabase? database) {
      final container = ProviderContainer(
        overrides: [libraryDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is true for a library path and false for another', () async {
      await db.upsertTracks([track(root, '/m/a')]);
      final container = containerWith(db);

      expect(
        await container.read(isLibraryPathProvider('/m/a').future),
        isTrue,
      );
      expect(
        await container.read(isLibraryPathProvider('/x/b').future),
        isFalse,
      );
    });

    test('is false without a library', () async {
      final container = containerWith(null);

      expect(
        await container.read(isLibraryPathProvider('/m/a').future),
        isFalse,
      );
    });
  });
}
