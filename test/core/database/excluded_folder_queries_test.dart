import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('adds a folder and reads its path back', () async {
    expect(await db.addExcludedFolder('/m/b', 5), isTrue);
    expect(await db.addExcludedFolder('/m/a', 6), isTrue);

    expect(await db.excludedFolderPaths(), unorderedEquals(['/m/a', '/m/b']));
    final stored = await db.select(db.excludedFolders).get();
    expect(stored.firstWhere((e) => e.path == '/m/b').addedAt, 5);
  });

  test('a path that is already excluded is not added twice', () async {
    expect(await db.addExcludedFolder('/m/a', 1), isTrue);
    expect(await db.addExcludedFolder('/m/a', 2), isFalse);

    final stored = await db.select(db.excludedFolders).get();
    expect(stored, hasLength(1));
    expect(stored.single.addedAt, 1);
  });

  test('removes one exclusion and ignores an unknown id', () async {
    await db.addExcludedFolder('/m/a', 1);
    await db.addExcludedFolder('/m/b', 1);
    final a = (await db.select(db.excludedFolders).get()).firstWhere(
      (e) => e.path == '/m/a',
    );

    await db.removeExcludedFolder(a.id);
    await db.removeExcludedFolder(9999);

    expect(await db.excludedFolderPaths(), ['/m/b']);
  });

  test('the watch emits the folders by path on every change', () async {
    final emitted = <List<String>>[];
    final sub = db.watchExcludedFolders().listen(
      (rows) => emitted.add([for (final r in rows) r.path]),
    );
    await pumpEventQueue();
    await db.addExcludedFolder('/m/b', 1);
    await pumpEventQueue();
    await db.addExcludedFolder('/m/a', 1);
    await pumpEventQueue();
    await sub.cancel();

    expect(emitted, [
      <String>[],
      ['/m/b'],
      ['/m/a', '/m/b'],
    ]);
  });
}
