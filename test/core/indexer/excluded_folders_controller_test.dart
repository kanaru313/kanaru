import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/excluded_folders_controller.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/root_path.dart';

import 'scripted_indexer.dart';

/// Makes adding an exclusion fail, as a full disk would.
Future<void> _failWrites(LibraryDatabase db) async {
  await db.customStatement(
    'CREATE TRIGGER no_insert BEFORE INSERT ON excluded_folders '
    "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
  );
}

void main() {
  late Directory tmp;
  late String base;
  late LibraryDatabase db;
  late ScriptedIndexer indexer;
  late ProviderContainer container;

  Future<void> start(LibraryDatabase database) async {
    db = database;
    indexer = ScriptedIndexer();
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        libraryIndexerProvider.overrideWith(() => indexer),
      ],
    );
    await db.addRoots(['$base/music'], now: 1);
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('excluded_test');
    base = tmp.resolveSymbolicLinksSync();
    for (final d in [
      'music/live',
      'music/live/deep',
      'music/Live Albums',
      'other',
    ]) {
      Directory('$base/$d').createSync(recursive: true);
    }
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ExcludedFoldersController controller() =>
      container.read(excludedFoldersControllerProvider);

  test('excludes a folder below a library folder and scans once', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));

    final result = await controller().add('$base/music/live/');

    expect(result, (rejection: null, conflict: null));
    expect(await db.excludedFolderPaths(), ['$base/music/live']);
    expect(indexer.scans, 1);
    expect(indexer.lastQuiet, isFalse);
  });

  test('a folder inside another exclusion is allowed', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    await controller().add('$base/music/live');

    final result = await controller().add('$base/music/live/deep');

    expect(result.conflict, isNull);
    expect(await db.excludedFolderPaths(), hasLength(2));
  });

  test('a library folder cannot be excluded', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));

    final result = await controller().add('$base/music');

    expect(result.conflict, ExclusionConflict.sameAsRoot);
    expect(await db.excludedFolderPaths(), isEmpty);
    expect(indexer.scans, 0);
  });

  test('a folder outside every library folder is refused', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));

    final result = await controller().add('$base/other');

    expect(result.conflict, ExclusionConflict.outsideLibrary);
    expect(indexer.scans, 0);
  });

  test('a parent of a library folder is outside the library', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));

    final result = await controller().add(base);

    expect(result.conflict, ExclusionConflict.outsideLibrary);
  });

  test('a symlink inside a library folder to the outside is refused', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    Link('$base/music/link').createSync('$base/other');

    final result = await controller().add('$base/music/link');

    expect(result.conflict, ExclusionConflict.outsideLibrary);
    expect(await db.excludedFolderPaths(), isEmpty);
  });

  test('the same folder twice is refused the second time', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    await controller().add('$base/music/live');

    final result = await controller().add('$base/music/live');

    expect(result.conflict, ExclusionConflict.alreadyExcluded);
    expect(indexer.scans, 1);
  });

  test('overlapping adds of one folder store it once', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));

    final results = await Future.wait([
      controller().add('$base/music/live'),
      controller().add('$base/music/live'),
    ]);

    expect(results.where((r) => r.conflict != null), hasLength(1));
    expect(await db.excludedFolderPaths(), hasLength(1));
  });

  test('says why a path is not a folder', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    File('$base/music/file.txt').writeAsStringSync('x');

    expect(
      (await controller().add('$base/music/gone')).rejection,
      RootRejection.notFound,
    );
    expect(
      (await controller().add('$base/music/file.txt')).rejection,
      RootRejection.notDirectory,
    );
    expect((await controller().add('/')).rejection, RootRejection.tooBroad);
    expect(indexer.scans, 0);
  });

  test('without a database the add is refused', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    container.dispose();
    container = ProviderContainer(
      overrides: LibraryStartup(db: null).overrides,
    );

    final result = await container
        .read(excludedFoldersControllerProvider)
        .add('$base/music/live');

    expect(result.rejection, RootRejection.libraryUnavailable);
  });

  test('a failed write is reported and does not scan', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    await _failWrites(db);

    final result = await controller().add('$base/music/live');

    expect(result.rejection, RootRejection.writeFailed);
    expect(indexer.scans, 0);
  });

  test('removing an exclusion deletes the row and scans once', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    await controller().add('$base/music/live');
    final id = (await db.select(db.excludedFolders).getSingle()).id;

    expect(await controller().remove(id), isTrue);

    expect(await db.excludedFolderPaths(), isEmpty);
    expect(indexer.scans, 2);
  });

  test('a failed removal is reported and does not scan', () async {
    await start(LibraryDatabase(NativeDatabase.memory()));
    await db.addExcludedFolder('$base/music/live', 1);
    final id = (await db.select(db.excludedFolders).getSingle()).id;
    await db.customStatement(
      'CREATE TRIGGER no_delete BEFORE DELETE ON excluded_folders '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );

    expect(await controller().remove(id), isFalse);
    expect(indexer.scans, 0);
  });
}
