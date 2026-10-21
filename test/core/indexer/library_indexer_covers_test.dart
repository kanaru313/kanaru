import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/root_scan_result.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';

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

  ProviderContainer containerFor(
    LibraryDatabase db, {
    String? coverDir,
    ScanTimeouts timeouts = const ScanTimeouts(),
  }) => ProviderContainer(
    overrides: [
      ...LibraryStartup(db: db, coverCacheDirectory: coverDir).overrides,
      tagReaderProvider.overrideWithValue(reader),
      scanTimeoutsProvider.overrideWithValue(timeouts),
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
  Future<Track> storedAt(String path) =>
      (db.select(db.tracks)..where((t) => t.path.equals(path))).getSingle();
  Future<Track> stored(String rel) => storedAt('$root/$rel');
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

      expect(reader.readCount, 0, reason: 'tags are not read again');
      expect(reader.coverCount, 1);
      expect(summary().updated, 0);
      final row = await stored('a.mp3');
      expect(row.coverKey, fakeCoverKey('red'));
      expect(row.coverScanVersion, coverScanVersion);
    },
  );

  test(
    'a file changed while covers were off gets its new cover later',
    () async {
      reader.coverByName['a.mp3'] = 'red';
      final a = touch('a.mp3');
      await scan();

      final coversOff = containerFor(db);
      addTearDown(coversOff.dispose);
      reader
        ..coverDirectory = null
        ..coverByName['a.mp3'] = 'blue'
        ..reset();
      change(a);
      await coversOff.read(libraryIndexerProvider.notifier).scan();
      expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));

      expect(reader.coverCount, 0, reason: 'no cover pass with covers off');
      reader
        ..coverDirectory = covers
        ..reset();
      await scan();

      expect(reader.readCount, 0);
      expect(reader.coverCount, 1);
      final row = await stored('a.mp3');
      expect(row.coverKey, fakeCoverKey('blue'));
      expect(row.coverScanVersion, coverScanVersion);
    },
  );

  test('tracks from before covers get one cover lookup, not counted', () async {
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
    expect(reader.readCount, 0);
    expect(reader.coverCount, 2);
    expect(summary().added, 0);
    expect(summary().updated, 0);
    expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));

    reader.reset();
    await scan();
    expect(reader.coverCount, 0);
  });

  test('one rescan brings back a wiped cover cache', () async {
    reader.coverByName.addAll({'a.mp3': 'red', 'b.mp3': 'blue'});
    touch('a.mp3');
    touch('b.mp3');
    await scan();

    Directory(covers).deleteSync(recursive: true);
    reader.reset();
    await scan();

    expect(reader.readCount, 0);
    expect(reader.coverCount, 2);
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

    expect(reader.coverCount, 2);
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

  test(
    'a cover folder that cannot be created does not re-read the library',
    () async {
      File('${tmp.path}/blocked').writeAsStringSync('x');
      final blocked = containerFor(db, coverDir: '${tmp.path}/blocked/covers');
      addTearDown(blocked.dispose);
      reader.coverDirectory = null;
      touch('a.mp3');
      touch('b.mp3');
      final indexer = blocked.read(libraryIndexerProvider.notifier);
      await indexer.scan();
      expect((await stored('a.mp3')).coverScanVersion, 0);

      reader.reset();
      await indexer.scan();

      expect(blocked.read(libraryIndexerProvider), isA<IndexerFinished>());
      expect(reader.readCount, 0, reason: 'unchanged files are not read again');
      expect(reader.coverCount, 0);
    },
  );

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

  group('two passes', () {
    test(
      'tags are stored and published before the first cover lookup',
      () async {
        reader.coverByName['a.mp3'] = 'red';
        touch('a.mp3');
        reader.hangingCovers.add('a.mp3');
        final scanning = scan();
        while (reader.coverBatches.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        expect(container.read(libraryIndexerProvider), isA<IndexerFinished>());
        final before = await stored('a.mp3');
        expect(before.title, 'A.MP3');
        expect(before.coverKey, isNull);

        reader.releaseHangingCovers();
        await scanning;
        expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));
      },
    );

    test('a failing root does not stop the covers of the others', () async {
      final other = '${tmp.resolveSymbolicLinksSync()}/other';
      Directory(other).createSync();
      File('$other/z.mp3').writeAsStringSync('x');
      await db.addRoots([other], now: 2);
      reader.coverByName.addAll({'a.mp3': 'red', 'z.mp3': 'green'});
      touch('a.mp3');
      await scan();
      thumbnail('old')
        ..createSync(recursive: true)
        ..setLastModifiedSync(DateTime(2000));

      // The first root throws on its tag batch; the other one is fine.
      final a = touch('a.mp3');
      change(a);
      File('$other/y.mp3').writeAsStringSync('x');
      // Both roots have covers to look up again; only the healthy one may.
      await db.customStatement('UPDATE tracks SET cover_scan_version = 0');
      reader
        ..coverByName['y.mp3'] = 'blue'
        ..reset()
        ..failOnBatch = 1;
      final states = <IndexerState>[];
      container.listen(libraryIndexerProvider, (_, next) => states.add(next));
      await scan();

      expect(states.whereType<IndexerFailed>(), hasLength(1));
      expect((await storedAt('$other/y.mp3')).coverKey, fakeCoverKey('blue'));
      expect(
        reader.coverBatches.expand((b) => b),
        everyElement(startsWith(other)),
      );
      expect(
        reader.coverBatches.expand((b) => b),
        containsAll(['$other/y.mp3', '$other/z.mp3']),
      );
      expect(thumbnail('old').existsSync(), isTrue, reason: 'no cleanup');
    });

    test('a cover reader that throws leaves the scan finished', () async {
      reader.coverByName['a.mp3'] = 'red';
      touch('a.mp3');
      thumbnail('old')
        ..createSync(recursive: true)
        ..setLastModifiedSync(DateTime(2000));
      reader.throwOnCovers = StateError('native library broke');
      await scan();

      expect(container.read(libraryIndexerProvider), isA<IndexerFinished>());
      expect((await stored('a.mp3')).coverScanVersion, 0);
      expect(thumbnail('old').existsSync(), isTrue, reason: 'no cleanup');
    });

    test(
      'a cover batch that hangs ends the scan; tags still read meanwhile',
      () async {
        final quick = containerFor(
          db,
          coverDir: covers,
          timeouts: const ScanTimeouts(tagBatch: Duration(milliseconds: 50)),
        );
        addTearDown(quick.dispose);
        final indexer = quick.read(libraryIndexerProvider.notifier);
        reader.coverByName.addAll({'a.mp3': 'red', 'b.mp3': 'blue'});
        reader.hangingCovers.add('a.mp3');
        final a = touch('a.mp3');
        touch('b.mp3');
        await indexer.scan();
        expect(quick.read(libraryIndexerProvider), isA<IndexerFinished>());
        expect((await stored('a.mp3')).coverScanVersion, 0);

        // Still hanging: the next scan reads tags but starts no cover pass.
        change(a);
        reader.reset();
        await indexer.scan();
        expect(reader.readCount, 1);
        expect(reader.coverCount, 0);

        reader.releaseHangingCovers();
        await Future<void>.delayed(Duration.zero);
        reader.reset();
        await indexer.scan();
        expect(reader.coverCount, 2);
        expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));
        expect((await stored('b.mp3')).coverKey, fakeCoverKey('blue'));
      },
    );

    test('a rescan makes the pass yield; the follow-up resumes', () async {
      for (var i = 0; i < 40; i++) {
        final name = 'f${i.toString().padLeft(2, '0')}.mp3';
        touch(name);
        reader.coverByName[name] = 'c$i';
      }
      reader.hangingCovers.add('f00.mp3');
      final first = scan();
      while (reader.coverBatches.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final second = scan();
      reader.releaseHangingCovers();
      await Future.wait([first, second]);

      expect(reader.coverBatches.map((b) => b.length), [32, 8]);
      expect(reader.coverCount, 40, reason: 'nothing looked up twice');
      expect((await stored('f39.mp3')).coverKey, fakeCoverKey('c39'));
    });

    test(
      'a failed cover is retried by the next scan the user asks for',
      () async {
        reader.failingCovers.add('a.mp3');
        reader.coverByName['b.mp3'] = 'blue';
        touch('a.mp3');
        touch('b.mp3');
        await scan();
        expect(reader.coverCount, 2);

        reader
          ..failingCovers.clear()
          ..coverByName['a.mp3'] = 'red'
          ..reset();
        await scan();
        expect(reader.coverBatches, [
          ['$root/a.mp3'],
        ]);
        expect((await stored('a.mp3')).coverKey, fakeCoverKey('red'));
      },
    );

    test('covers of a missing root are not looked up', () async {
      final other = '${tmp.resolveSymbolicLinksSync()}/other';
      Directory(other).createSync();
      File('$other/z.mp3').writeAsStringSync('x');
      await db.addRoots([other], now: 2);
      reader.coverByName['z.mp3'] = 'green';
      await scan();
      expect((await storedAt('$other/z.mp3')).coverKey, fakeCoverKey('green'));

      Directory(other).deleteSync(recursive: true);
      await db.customStatement('UPDATE tracks SET cover_scan_version = 0');
      reader.reset();
      await scan();

      expect(reader.coverCount, 0);
      expect((await storedAt('$other/z.mp3')).coverKey, fakeCoverKey('green'));
    });

    test('a malformed key from the reader is not stored', () async {
      final bad = _BadKeyReader()..coverDirectory = covers;
      final odd = ProviderContainer(
        overrides: [
          ...LibraryStartup(db: db, coverCacheDirectory: covers).overrides,
          tagReaderProvider.overrideWithValue(bad),
        ],
      );
      addTearDown(odd.dispose);
      touch('a.mp3');
      await odd.read(libraryIndexerProvider.notifier).scan();

      final row = await stored('a.mp3');
      expect(row.coverKey, isNull);
      expect(row.coverScanVersion, 0);
    });
  });
}

/// Answers every cover lookup with a key that could point outside the cover
/// folder.
class _BadKeyReader extends FakeTagReader {
  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async => [
    for (final path in paths)
      TrackCover(path: path, cover: '../../etc/x', status: CoverStatus.found),
  ];
}
