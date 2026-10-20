import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';

import 'fake_tag_reader.dart';

/// Fails every cover key lookup, like a database error during the cover
/// cache steps.
class _CoverQueryFailingDb extends LibraryDatabase {
  _CoverQueryFailingDb() : super(NativeDatabase.memory());

  @override
  Future<Set<String>> coverKeysInUse() => throw StateError('db broke');
}

void main() {
  late Directory tmp;
  late String root;
  late String covers;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;

  ProviderContainer containerFor(LibraryDatabase db, {String? coverDir}) =>
      ProviderContainer(
        overrides: [
          ...LibraryStartup(db: db, coverCacheDirectory: coverDir).overrides,
          tagReaderProvider.overrideWithValue(reader),
        ],
      );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_covers_test');
    final base = tmp.resolveSymbolicLinksSync();
    root = '$base/music';
    covers = '$base/cache/covers/512';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader()..coverDirectory = covers;
    container = containerFor(db, coverDir: covers);
    await db.addRoots([root], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File touch(String rel) => File('$root/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  void change(File file) =>
      file.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  ScanSummary summary() =>
      (container.read(libraryIndexerProvider) as IndexerFinished).summary;
  Future<Track> stored(String rel) => (db.select(
    db.tracks,
  )..where((t) => t.path.equals('$root/$rel'))).getSingle();
  File thumbnail(String cover) => File('$covers/${fakeCoverKey(cover)}');
  List<String> cachedFiles() => Directory(covers).existsSync()
      ? [
          for (final f in Directory(covers).listSync(recursive: true))
            if (f is File) f.path.substring(covers.length + 1),
        ]
      : const [];

  test(
    'without a cover folder nothing is written and keys stay empty',
    () async {
      final plain = containerFor(db);
      addTearDown(plain.dispose);
      reader.coverDirectory = null;
      touch('a.mp3');
      await plain.read(libraryIndexerProvider.notifier).scan();

      expect(plain.read(coverCacheDirectoryProvider), isNull);
      expect((await stored('a.mp3')).coverKey, isNull);
      expect((await stored('a.mp3')).coverScanVersion, 0);
      expect(Directory('${tmp.path}/cache').existsSync(), isFalse);
    },
  );

  test('a first scan stores each cover key and stamps the version', () async {
    reader.coverByName['a.mp3'] = 'red';
    touch('a.mp3');
    touch('b.mp3');
    await scan();

    final a = await stored('a.mp3'), b = await stored('b.mp3');
    expect(a.coverKey, fakeCoverKey('red'));
    expect(a.coverScanVersion, coverScanVersion);
    expect(b.coverKey, isNull, reason: 'no cover found');
    expect(b.coverScanVersion, coverScanVersion);
    expect(cachedFiles(), [fakeCoverKey('red')]);
  });

  test(
    'a changed file gets its new cover and the old one is deleted',
    () async {
      reader.coverByName['a.mp3'] = 'red';
      final a = touch('a.mp3');
      await scan();

      reader.coverByName['a.mp3'] = 'blue';
      change(a);
      await scan();

      expect((await stored('a.mp3')).coverKey, fakeCoverKey('blue'));
      expect(thumbnail('red').existsSync(), isFalse);
      expect(cachedFiles(), [fakeCoverKey('blue')]);
    },
  );

  test('a deleted file takes its own cover along, not a shared one', () async {
    reader.coverByName.addAll({
      'a.mp3': 'red',
      'b.mp3': 'green',
      'c.mp3': 'green',
    });
    final a = touch('a.mp3');
    final b = touch('b.mp3');
    touch('c.mp3');
    await scan();

    a.deleteSync();
    b.deleteSync();
    await scan();

    expect(summary().removed, 2);
    expect(thumbnail('red').existsSync(), isFalse);
    expect(thumbnail('green').existsSync(), isTrue);
  });

  test('a cover removed from a file clears its key and file', () async {
    reader.coverByName['a.mp3'] = 'red';
    final a = touch('a.mp3');
    await scan();

    reader.coverByName.remove('a.mp3');
    change(a);
    await scan();

    final row = await stored('a.mp3');
    expect(row.coverKey, isNull);
    expect(row.coverScanVersion, coverScanVersion);
    expect(cachedFiles(), isEmpty);
  });

  test(
    'a failed cover is not stamped and is retried on the next scan',
    () async {
      reader.failingCovers.add('a.mp3');
      touch('a.mp3');
      await scan();
      expect((await stored('a.mp3')).coverScanVersion, 0);

      reader
        ..failingCovers.clear()
        ..coverByName['a.mp3'] = 'red'
        ..reset();
      await scan();

      expect(reader.readCount, 1);
      expect(summary().updated, 0);
      final row = await stored('a.mp3');
      expect(row.coverKey, fakeCoverKey('red'));
      expect(row.coverScanVersion, coverScanVersion);
    },
  );

  test('tracks from before covers are read once, not counted', () async {
    reader.coverByName['a.mp3'] = 'red';
    touch('a.mp3');
    touch('b.mp3');
    await scan();
    // As after the v1 to v2 migration.
    await db.customStatement(
      'UPDATE tracks SET cover_scan_version = 0, cover_key = NULL',
    );

    reader.reset();
    await scan();
    expect(reader.readCount, 2);
    expect(summary().added, 0);
    expect(summary().updated, 0);
    expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));

    reader.reset();
    await scan();
    expect(reader.readCount, 0);
  });

  test('one rescan brings back a wiped cover cache', () async {
    reader.coverByName.addAll({'a.mp3': 'red', 'b.mp3': 'blue'});
    touch('a.mp3');
    touch('b.mp3');
    await scan();

    Directory(covers).deleteSync(recursive: true);
    reader.reset();
    await scan();

    expect(reader.readCount, 2);
    expect(thumbnail('red').existsSync(), isTrue);
    expect(thumbnail('blue').existsSync(), isTrue);
    expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));
  });

  test('one rescan brings back a single lost or emptied thumbnail', () async {
    reader.coverByName.addAll({'a.mp3': 'red', 'b.mp3': 'blue'});
    touch('a.mp3');
    touch('b.mp3');
    await scan();

    thumbnail('red').deleteSync();
    thumbnail('blue').writeAsStringSync('');
    reader.reset();
    await scan();

    expect(reader.readCount, 2);
    expect(thumbnail('red').existsSync(), isTrue);
    expect(thumbnail('blue').lengthSync(), greaterThan(0));
  });

  test('covers of a skipped root are kept', () async {
    final other = '${tmp.resolveSymbolicLinksSync()}/other';
    Directory(other).createSync();
    File('$other/z.mp3').writeAsStringSync('x');
    await db.addRoots([other], now: 2);
    reader.coverByName.addAll({'a.mp3': 'red', 'z.mp3': 'green'});
    touch('a.mp3');
    await scan();

    Directory(other).deleteSync(recursive: true);
    await scan();

    expect(summary().skippedRoots, contains(other));
    expect(thumbnail('green').existsSync(), isTrue);
  });

  test('a broken cover folder or database never fails the scan', () async {
    File('${tmp.path}/not-a-folder').writeAsStringSync('x');
    final broken = containerFor(db, coverDir: '${tmp.path}/not-a-folder');
    addTearDown(broken.dispose);
    reader.coverDirectory = null;
    touch('a.mp3');
    await broken.read(libraryIndexerProvider.notifier).scan();
    expect(broken.read(libraryIndexerProvider), isA<IndexerFinished>());

    final failingDb = _CoverQueryFailingDb();
    addTearDown(failingDb.close);
    await failingDb.addRoots([root], now: 1);
    final failing = containerFor(failingDb, coverDir: covers);
    addTearDown(failing.dispose);
    await failing.read(libraryIndexerProvider.notifier).scan();
    expect(failing.read(libraryIndexerProvider), isA<IndexerFinished>());
  });

  test('a scan that fails part way deletes no cover', () async {
    reader.coverByName['a.mp3'] = 'red';
    final a = touch('a.mp3');
    await scan();
    // An orphan from an earlier run that a full scan would delete.
    thumbnail('old')
      ..createSync(recursive: true)
      ..setLastModifiedSync(DateTime(2000));

    change(a);
    reader.throwOnRead = StateError('native library missing');
    await scan();

    expect(container.read(libraryIndexerProvider), isA<IndexerFailed>());
    expect(thumbnail('old').existsSync(), isTrue);
    expect(thumbnail('red').existsSync(), isTrue);
  });
}
