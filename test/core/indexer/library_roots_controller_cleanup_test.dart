import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';

import '../cover_colors/fake_cover_color_extractor.dart';
import 'fake_tag_reader.dart';

/// A database whose cleanup of colors fails.
class _CleanupFailingDb extends LibraryDatabase {
  _CleanupFailingDb(super.e);

  @override
  Future<Set<String>> coverKeysInUse() => Future.error(StateError('disk'));
}

void main() {
  late Directory tmp;
  late String base, covers;
  late LibraryDatabase db;
  late ProviderContainer container;
  late int rootA, rootB;
  final old = DateTime(2000);

  Future<void> open(LibraryDatabase database, {String? coverDir}) async {
    db = database;
    container = ProviderContainer(
      overrides: LibraryStartup(
        db: db,
        hasRoots: true,
        coverCacheDirectory: coverDir,
      ).overrides,
    );
    [rootA, rootB] = await db.addRoots(['$base/a', '$base/b'], now: 1);
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('roots_cleanup_test');
    base = tmp.resolveSymbolicLinksSync();
    for (final d in ['a', 'b', 'c']) {
      Directory('$base/$d').createSync();
    }
    covers = '$base/covers/512';
    Directory(covers).createSync(recursive: true);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> track(int root, String name, String cover) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: root,
      path: '$base/${root == rootA ? 'a' : 'b'}/$name',
      mtimeMs: 1,
      sizeBytes: 1,
      title: name,
      addedAt: 1,
      updatedAt: 1,
      coverKey: Value(fakeCoverKey(cover)),
      coverScanVersion: const Value(coverScanVersion),
    ),
  ]);

  File cached(String cover) => File('$covers/${fakeCoverKey(cover)}')
    ..createSync(recursive: true)
    ..writeAsStringSync('x')
    ..setLastModifiedSync(old);

  Future<Set<String>> colorKeys() async => {
    for (final row in await db.select(db.coverColors).get()) row.coverKey,
  };

  /// Root A has cover `onlyA`, root B `onlyB`, both have `shared`; every
  /// cover has a thumbnail and colors.
  Future<Map<String, File>> twoRoots() async {
    await track(rootA, '1.mp3', 'onlyA');
    await track(rootA, '2.mp3', 'shared');
    await track(rootB, '3.mp3', 'onlyB');
    await track(rootB, '4.mp3', 'shared');
    await db.upsertCoverColors([
      for (final c in ['onlyA', 'onlyB', 'shared']) sampleFor(fakeCoverKey(c)),
    ]);
    return {
      for (final c in ['onlyA', 'onlyB', 'shared']) c: cached(c),
    };
  }

  test('removing a folder deletes its own thumbnails and colors', () async {
    await open(LibraryDatabase(NativeDatabase.memory()), coverDir: covers);
    final files = await twoRoots();
    final result = await container
        .read(libraryRootsControllerProvider)
        .removeRoot(rootA);
    expect(result.ok, isTrue);
    expect(files['onlyA']!.existsSync(), isFalse);
    expect(files['shared']!.existsSync(), isTrue);
    expect(files['onlyB']!.existsSync(), isTrue);
    expect(await colorKeys(), {fakeCoverKey('onlyB'), fakeCoverKey('shared')});
  });

  test('removing the last folder leaves no thumbnail and no color', () async {
    await open(LibraryDatabase(NativeDatabase.memory()), coverDir: covers);
    final files = await twoRoots();
    final controller = container.read(libraryRootsControllerProvider);
    await controller.removeRoot(rootA);
    await controller.removeRoot(rootB);
    expect(files.values.where((f) => f.existsSync()), isEmpty);
    expect(await colorKeys(), isEmpty);
  });

  test('a running cover pass keeps the thumbnails, not the colors', () async {
    await open(LibraryDatabase(NativeDatabase.memory()), coverDir: covers);
    final files = await twoRoots();
    container.read(coverPassProvider.notifier).report(1, 10);
    await container.read(libraryRootsControllerProvider).removeRoot(rootA);
    expect(files['onlyA']!.existsSync(), isTrue);
    expect(await colorKeys(), {fakeCoverKey('onlyB'), fakeCoverKey('shared')});
  });

  test('without a cover folder only the colors are cleaned', () async {
    await open(LibraryDatabase(NativeDatabase.memory()));
    final files = await twoRoots();
    await container.read(libraryRootsControllerProvider).removeRoot(rootA);
    expect(files['onlyA']!.existsSync(), isTrue);
    expect(await colorKeys(), {fakeCoverKey('onlyB'), fakeCoverKey('shared')});
  });

  test('replacing a folder deletes its colors and keeps thumbnails', () async {
    await open(LibraryDatabase(NativeDatabase.memory()), coverDir: covers);
    final files = await twoRoots();
    final result = await container
        .read(libraryRootsControllerProvider)
        .replaceRoot(rootA, '$base/c');
    expect(result.ok, isTrue);
    expect(files['onlyA']!.existsSync(), isTrue);
    expect(await colorKeys(), {fakeCoverKey('onlyB'), fakeCoverKey('shared')});
  });

  test('a failed cleanup still reports the removal', () async {
    await open(_CleanupFailingDb(NativeDatabase.memory()), coverDir: covers);
    final files = await twoRoots();
    final result = await container
        .read(libraryRootsControllerProvider)
        .removeRoot(rootA);
    expect(result.ok, isTrue);
    expect(files['onlyA']!.existsSync(), isTrue);
    expect(await colorKeys(), {fakeCoverKey('onlyB'), fakeCoverKey('shared')});
  });
}
