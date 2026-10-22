import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/cover_cache_cleanup.dart';

import '../cover_colors/fake_cover_color_extractor.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String covers;
  late LibraryDatabase db;
  late int rootId;
  final old = DateTime(2000);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cover_cleanup_colors_test');
    covers = '${tmp.resolveSymbolicLinksSync()}/covers/512';
    Directory(covers).createSync(recursive: true);
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> track(String name, String? cover) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/$name',
      mtimeMs: 1,
      sizeBytes: 1,
      title: name,
      addedAt: 1,
      updatedAt: 1,
      coverKey: Value(cover == null ? null : fakeCoverKey(cover)),
      coverScanVersion: const Value(coverScanVersion),
    ),
  ]);

  File cached(String cover, {DateTime? modified}) =>
      File('$covers/${fakeCoverKey(cover)}')
        ..createSync(recursive: true)
        ..writeAsStringSync('x')
        ..setLastModifiedSync(modified ?? old);

  Future<Set<String>> colorKeys() async => {
    for (final row in await db.select(db.coverColors).get()) row.coverKey,
  };

  test(
    'the scan cleanup deletes unused colors, also next to a NULL cover',
    () async {
      await track('a.mp3', 'a');
      await track('none.mp3', null);
      await db.upsertCoverColors([
        sampleFor(fakeCoverKey('a')),
        sampleFor(fakeCoverKey('gone')),
      ]);
      await cleanCoverCache(db, covers, DateTime.now());
      expect(await colorKeys(), {fakeCoverKey('a')});
    },
  );

  test('repairing missing thumbnails keeps the colors', () async {
    await track('a.mp3', 'a');
    await db.upsertCoverColors([sampleFor(fakeCoverKey('a'))]);
    // The thumbnail is missing, so the repair resets the track's cover.
    expect(await repairMissingCovers(db, covers), 1);
    expect(await colorKeys(), {fakeCoverKey('a')});
  });

  group('deleteUnusedThumbnails', () {
    test('deletes only the given keys, and only older files', () async {
      final mine = cached('mine');
      final fresh = cached('fresh', modified: DateTime.now());
      final other = cached('other');
      final deleted = await deleteUnusedThumbnails(covers, {
        fakeCoverKey('mine'),
        fakeCoverKey('fresh'),
      }, before: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(deleted, 1);
      expect(mine.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
    });

    test('never follows a linked shard folder', () async {
      final outside = Directory('${tmp.path}/outside')..createSync();
      final key = fakeCoverKey('linked');
      final target = File('${outside.path}/${key.substring(3)}')
        ..writeAsStringSync('x')
        ..setLastModifiedSync(old);
      Link('$covers/${key.substring(0, 2)}').createSync(outside.path);
      expect(
        await deleteUnusedThumbnails(covers, {key}, before: DateTime.now()),
        0,
      );
      expect(target.existsSync(), isTrue);
    });

    test('ignores malformed keys and leaves temp files', () async {
      final temp = File('$covers/ab/.kanaru-tmp123')
        ..createSync(recursive: true)
        ..setLastModifiedSync(old);
      expect(
        await deleteUnusedThumbnails(covers, {
          '../x.jpg',
          'ab/.kanaru-tmp123',
        }, before: DateTime.now()),
        0,
      );
      expect(temp.existsSync(), isTrue);
    });

    test('an empty key set touches nothing', () async {
      expect(
        await deleteUnusedThumbnails(
          '/nonexistent',
          {},
          before: DateTime.now(),
        ),
        0,
      );
    });
  });
}
