import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/library_track_of_path.dart';

import 'library_database_test.dart' show track;

void main() {
  late LibraryDatabase db;
  late int root;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    root = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  ProviderContainer containerWith(LibraryDatabase? database) {
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('gives the row of a library path with its id', () async {
    await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);
    final container = containerWith(db);

    final item = await container.read(
      libraryTrackOfPathProvider('/m/b').future,
    );

    expect(item, isNotNull);
    expect(item!.path, '/m/b');
    expect(item.id, isPositive);
  });

  test('is null for a path the library does not know', () async {
    await db.upsertTracks([track(root, '/m/a')]);
    final container = containerWith(db);

    expect(
      await container.read(libraryTrackOfPathProvider('/x/b').future),
      isNull,
    );
  });

  test('is null without a library', () async {
    final container = containerWith(null);

    expect(
      await container.read(libraryTrackOfPathProvider('/m/a').future),
      isNull,
    );
  });

  test('is null when the read fails', () async {
    final container = containerWith(db);
    await db.close();

    expect(
      await container.read(libraryTrackOfPathProvider('/m/a').future),
      isNull,
    );
  });
}
