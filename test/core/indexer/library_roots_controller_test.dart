import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/library_roots_controller.dart';
import 'package:kanaru/core/indexer/root_path.dart';

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
}
