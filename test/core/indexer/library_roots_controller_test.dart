import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/library_roots_controller.dart';
import 'package:kanaru/core/indexer/root_path.dart';

/// A database whose writes of roots fail.
class _WriteFailingDb extends LibraryDatabase {
  _WriteFailingDb(super.e);

  @override
  Future<List<int>> addRoots(List<String> paths, {required int now}) =>
      Future.error(StateError('disk full'));
}

/// Makes deleting a root fail, as a full or read-only disk would.
Future<void> _failDeletes(LibraryDatabase db) => db.customStatement(
  'CREATE TRIGGER no_root_delete BEFORE DELETE ON library_roots '
  "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
);

void main() {
  late Directory tmp;
  late String base;
  late LibraryDatabase db;
  late ProviderContainer container;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('roots_test');
    base = tmp.resolveSymbolicLinksSync();
    for (final d in ['music', 'music2', 'music/rock', 'other']) {
      Directory('$base/$d').createSync(recursive: true);
    }
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: LibraryStartup(db: db).overrides);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  LibraryRootsController controller() =>
      container.read(libraryRootsControllerProvider);

  test('adds several roots and flips libraryHasRoots', () async {
    expect(container.read(libraryHasRootsProvider), isFalse);

    final result = await controller().addRoots(['$base/music/', '$base/other']);

    expect(result.added, ['$base/music', '$base/other']);
    expect(result.rejected, isEmpty);
    expect((await db.roots()).map((r) => r.path), result.added);
    expect(container.read(libraryHasRootsProvider), isTrue);
  });

  test('refuses duplicate, nested and sibling-prefix correctly', () async {
    await controller().addRoots(['$base/music']);

    final result = await controller().addRoots([
      '$base/music',
      '$base/music/rock',
      '$base/music2',
      '$base/missing',
    ]);

    expect(result.added, ['$base/music2']);
    expect(result.rejected, {
      '$base/music': RootRejection.duplicate,
      '$base/music/rock': RootRejection.nested,
      '$base/missing': RootRejection.notFound,
    });
  });

  test('refuses overlaps within one batch', () async {
    final result = await controller().addRoots([
      '$base/music/rock',
      '$base/music',
      '$base/other',
      '$base/other/',
    ]);

    expect(result.added, ['$base/music/rock', '$base/other']);
    expect(result.rejected['$base/music'], RootRejection.nested);
    expect(result.rejected['$base/other/'], RootRejection.duplicate);
  });

  test('nothing valid leaves libraryHasRoots false', () async {
    final result = await controller().addRoots(['$base/missing']);

    expect(result.added, isEmpty);
    expect(container.read(libraryHasRootsProvider), isFalse);
  });

  test('without a database every path is refused', () async {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);

    final result = await bare.read(libraryRootsControllerProvider).addRoots([
      '$base/music',
    ]);

    expect(result.rejected, {'$base/music': RootRejection.libraryUnavailable});
  });

  test('/ is refused as too broad', () async {
    final result = await controller().addRoots(['/', '$base/other']);

    expect(result.rejected, {'/': RootRejection.tooBroad});
    expect(result.added, ['$base/other']);
  });

  test('a failing write refuses every path and does not throw', () async {
    final failing = _WriteFailingDb(NativeDatabase.memory());
    addTearDown(failing.close);
    final c = ProviderContainer(
      overrides: LibraryStartup(db: failing).overrides,
    );
    addTearDown(c.dispose);

    final result = await c.read(libraryRootsControllerProvider).addRoots([
      '$base/music',
      '$base/other',
      '$base/missing',
    ]);

    expect(result.added, isEmpty);
    expect(result.rejected, {
      '$base/music': RootRejection.writeFailed,
      '$base/other': RootRejection.writeFailed,
      '$base/missing': RootRejection.notFound,
    });
    expect(c.read(libraryHasRootsProvider), isFalse);
  });

  group('overlapping calls', () {
    test('the same folder twice is stored once and refused once', () async {
      final results = await Future.wait([
        controller().addRoots(['$base/music']),
        controller().addRoots(['$base/music']),
      ]);

      expect((await db.roots()).map((r) => r.path), ['$base/music']);
      expect(results[0].added, ['$base/music']);
      expect(results[1].added, isEmpty);
      expect(results[1].rejected, {'$base/music': RootRejection.duplicate});
    });

    test('a folder and its parent are not both stored', () async {
      final results = await Future.wait([
        controller().addRoots(['$base/music/rock']),
        controller().addRoots(['$base/music']),
      ]);

      expect((await db.roots()).map((r) => r.path), ['$base/music/rock']);
      expect(results[1].added, isEmpty);
      expect(results[1].rejected, hasLength(1));
    });

    test('unrelated folders added together are all kept', () async {
      await Future.wait([
        controller().addRoots(['$base/music']),
        controller().addRoots(['$base/other']),
        controller().addRoots(['$base/music2']),
      ]);

      expect((await db.roots()).map((r) => r.path).toSet(), {
        '$base/music',
        '$base/other',
        '$base/music2',
      });
    });
  });

  group('removeRoot', () {
    test('drops the root and flips libraryHasRoots after the last', () async {
      await controller().addRoots(['$base/music', '$base/other']);
      final roots = await db.roots();

      expect((await controller().removeRoot(roots[0].id)).ok, isTrue);
      expect(container.read(libraryHasRootsProvider), isTrue);
      expect((await controller().removeRoot(roots[1].id)).ok, isTrue);

      expect(await db.roots(), isEmpty);
      expect(container.read(libraryHasRootsProvider), isFalse);
    });

    test('an unknown id is a success', () async {
      expect((await controller().removeRoot(42)).ok, isTrue);
    });

    test('without a database it is refused', () async {
      final bare = ProviderContainer();
      addTearDown(bare.dispose);

      final result = await bare
          .read(libraryRootsControllerProvider)
          .removeRoot(1);

      expect(result.rejection, RootRejection.libraryUnavailable);
    });

    test('a failing write is reported, not thrown', () async {
      await db.addRoots(['$base/music'], now: 1);
      await _failDeletes(db);

      final result = await controller().removeRoot(1);

      expect(result.rejection, RootRejection.writeFailed);
    });

    test('runs after an add queued before it', () async {
      final add = controller().addRoots(['$base/music']);
      final remove = controller().removeRoot(1);
      await Future.wait([add, remove]);

      expect(await db.roots(), isEmpty);
      expect(container.read(libraryHasRootsProvider), isFalse);
    });
  });

  group('replaceRoot', () {
    late int musicId;
    setUp(() async {
      await controller().addRoots(['$base/music', '$base/other']);
      musicId = (await db.roots()).first.id;
    });

    Future<List<String>> paths() async => [
      for (final r in await db.roots()) r.path,
    ];

    test('re-points the root under a new id', () async {
      final result = await controller().replaceRoot(musicId, '$base/music2/');

      expect(result.ok, isTrue);
      expect(await paths(), ['$base/other', '$base/music2']);
      expect(await db.rootExists(musicId), isFalse);
    });

    test('the same folder changes nothing', () async {
      final result = await controller().replaceRoot(musicId, '$base/music/');

      expect(result.unchanged, isTrue);
      expect(result.ok, isTrue);
      expect((await db.roots()).first.id, musicId);
    });

    test('a parent or child of itself is fine', () async {
      expect(
        (await controller().replaceRoot(musicId, '$base/music/rock')).ok,
        isTrue,
      );
      expect(await paths(), ['$base/other', '$base/music/rock']);
    });

    test('overlap with another root is refused and nothing changes', () async {
      Directory('$base/other/deep').createSync();

      final nested = await controller().replaceRoot(
        musicId,
        '$base/other/deep',
      );
      final dup = await controller().replaceRoot(musicId, '$base/other');

      expect(nested.rejection, RootRejection.nested);
      expect(dup.rejection, RootRejection.duplicate);
      expect(await paths(), ['$base/music', '$base/other']);
    });

    test('a missing new folder is refused', () async {
      final result = await controller().replaceRoot(musicId, '$base/missing');

      expect(result.rejection, RootRejection.notFound);
      expect(await paths(), ['$base/music', '$base/other']);
    });

    test('an unknown id is refused without writing', () async {
      final result = await controller().replaceRoot(999, '$base/music2');

      expect(result.rejection, RootRejection.notFound);
      expect(await paths(), ['$base/music', '$base/other']);
    });

    test('a failing write is reported, not thrown', () async {
      await controller().addRoots(['$base/music']);
      await _failDeletes(db);

      final result = await controller().replaceRoot(1, '$base/music2');

      expect(result.rejection, RootRejection.writeFailed);
    });
  });
}
