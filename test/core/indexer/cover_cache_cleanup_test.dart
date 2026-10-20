import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/cover_cache_cleanup.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String covers;
  late LibraryDatabase db;
  late int rootId;
  final old = DateTime(2000);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cover_cleanup_test');
    covers = '${tmp.resolveSymbolicLinksSync()}/covers/512';
    Directory(covers).createSync(recursive: true);
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> trackWithCover(String name, String? cover) => db.upsertTracks([
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

  File write(String relative, {String content = 'x', DateTime? modified}) =>
      File('$covers/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(content)
        ..setLastModifiedSync(modified ?? old);

  File cached(String cover, {String content = 'x', DateTime? modified}) =>
      write(fakeCoverKey(cover), content: content, modified: modified);

  Future<Track> stored(String name) => (db.select(
    db.tracks,
  )..where((t) => t.path.equals('/m/$name'))).getSingle();

  group('repair', () {
    test('resets only tracks whose thumbnail is missing or empty', () async {
      await trackWithCover('a', 'red');
      await trackWithCover('b', 'blue');
      await trackWithCover('c', 'green');
      cached('red');
      cached('blue', content: '');

      expect(await repairMissingCovers(db, covers), 2);
      expect((await stored('a')).coverKey, fakeCoverKey('red'));
      for (final name in ['b', 'c']) {
        final row = await stored(name);
        expect(row.coverKey, isNull, reason: name);
        expect(row.coverScanVersion, 0, reason: name);
      }
    });

    test('a missing cover folder resets every key', () async {
      await trackWithCover('a', 'red');
      Directory(covers).deleteSync(recursive: true);

      expect(await repairMissingCovers(db, covers), 1);
      expect((await stored('a')).coverScanVersion, 0);
    });

    test('a folder that cannot be listed resets nothing', () async {
      await trackWithCover('a', 'red');
      File('${tmp.path}/file').writeAsStringSync('x');

      expect(await repairMissingCovers(db, '${tmp.path}/file'), isNull);
      expect((await stored('a')).coverKey, fakeCoverKey('red'));
    });
  });

  group('cleanup', () {
    test('deletes old orphans and temp files, keeps used covers', () async {
      await trackWithCover('a', 'red');
      final used = cached('red');
      final orphan = cached('blue');
      final temp = write(
        '${fakeCoverKey('x').substring(0, 2)}/.kanaru-tmpAb12',
      );

      expect(await cleanCoverCache(db, covers, DateTime.now()), 2);
      expect(used.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
      expect(temp.existsSync(), isFalse);
    });

    test('keeps orphans written since the scan started', () async {
      final started = DateTime.now().subtract(const Duration(minutes: 1));
      final fresh = cached('blue', modified: DateTime.now());

      expect(await cleanCoverCache(db, covers, started), 0);
      expect(fresh.existsSync(), isTrue);
    });

    test('never touches links, strange names or other sizes', () async {
      final key = fakeCoverKey('blue');
      final shard = key.substring(0, 2);
      final hash = key.substring(3, 3 + 64);
      final strangers = [
        write('$shard/$hash.png'),
        write('$shard/$hash.webp'),
        write('$shard/notes.txt'),
        write('zz/$hash.jpg'),
        write('$hash.jpg'),
      ];
      // A shard that is a link to a folder holding a thumbnail-like file.
      final elsewhere = Directory('${tmp.path}/elsewhere')..createSync();
      final target =
          File('${elsewhere.path}/${fakeCoverKey('green').substring(3)}')
            ..writeAsStringSync('x')
            ..setLastModifiedSync(old);
      Link('$covers/${fakeCoverKey('green').substring(0, 2)}')
          .createSync(elsewhere.path);
      // A thumbnail name that is a link to a file.
      Directory('$covers/$shard').createSync(recursive: true);
      final linked = File('${tmp.path}/linked')..writeAsStringSync('x');
      Link('$covers/$key').createSync(linked.path);
      // Thumbnails of another size live in a sibling folder.
      final sibling = File('${tmp.path}/covers/256/$key')
        ..createSync(recursive: true)
        ..setLastModifiedSync(old);

      expect(await cleanCoverCache(db, covers, DateTime.now()), 0);
      for (final file in [...strangers, target, linked, sibling]) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
      expect(Link('$covers/$key').existsSync(), isTrue);
    });

    test('a missing folder deletes nothing and does not throw', () async {
      Directory(covers).deleteSync(recursive: true);
      expect(await cleanCoverCache(db, covers, DateTime.now()), 0);
    });
  });
}
