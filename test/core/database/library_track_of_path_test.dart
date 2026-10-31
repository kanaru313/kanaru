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

  // The provider is autoDispose: hold it while its first value is awaited.
  Future<TrackListItem?> rowOf(ProviderContainer container, String path) {
    final provider = libraryTrackOfPathProvider(path);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('gives the row of a library path with its id', () async {
    await db.upsertTracks([track(root, '/m/a'), track(root, '/m/b')]);
    final container = containerWith(db);

    final item = await rowOf(container, '/m/b');

    expect(item, isNotNull);
    expect(item!.path, '/m/b');
    expect(item.id, isPositive);
  });

  test('is null for a path the library does not know', () async {
    await db.upsertTracks([track(root, '/m/a')]);
    final container = containerWith(db);

    expect(await rowOf(container, '/x/b'), isNull);
  });

  test('is null without a library', () async {
    final container = containerWith(null);

    expect(await rowOf(container, '/m/a'), isNull);
  });

  test('is null when the read fails', () async {
    final container = containerWith(db);
    await db.close();

    expect(await rowOf(container, '/m/a'), isNull);
  });

  test('turns null after a rescan drops the row', () async {
    await db.upsertTracks([track(root, '/m/a')]);
    final container = containerWith(db);
    final seen = <String?>[];
    container.listen(
      libraryTrackOfPathProvider('/m/a'),
      (_, next) => seen.add(next.value?.path),
      fireImmediately: true,
    );
    await rowOf(container, '/m/a');

    await db.delete(db.tracks).go();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(libraryTrackOfPathProvider('/m/a')).value, isNull);
    expect(seen, contains('/m/a'));
  });
}
