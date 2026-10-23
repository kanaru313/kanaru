import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/scan_stats_queries.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/scan_stats.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_stats_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader();
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(reader),
      ],
    );
    await db.addRoots([root], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  void touch(String rel, [String content = 'xxxxxxxxxx']) => File('$root/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  ScanStats? stats() => container.read(lastScanStatsProvider);

  test('nothing is published before a scan ends', () {
    expect(stats(), isNull);
  });

  test('every reason is counted, and the files seen are all of them', () async {
    touch('a.mp3');
    touch('b.mp3');
    touch('short.mp3');
    touch('quiet/c.mp3');
    touch('quiet/.nomedia', '');
    reader.durationByName['short.mp3'] = 5000;
    reader.durationByName['a.mp3'] = 60000;
    reader.durationByName['b.mp3'] = 60000;
    container
        .read(settingsProvider.notifier)
        .setLibraryScan(
          const LibraryScanPrefs(
            respectNomedia: true,
            minFileSizeKb: 0,
            minDurationSeconds: 10,
          ),
        );

    await scan();

    expect(
      stats(),
      const ScanStats(
        seen: 4,
        nomedia: 1,
        excluded: 0,
        tooSmall: 0,
        tooShort: 1,
        stored: 2,
      ),
    );
  });

  test('size and excluded folders are counted', () async {
    touch('a.mp3', 'x' * 3000);
    touch('tiny.mp3', 'x');
    touch('out/b.mp3', 'x' * 3000);
    await db.addExcludedFolder('$root/out', 1);
    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(minFileSizeKb: 1));

    await scan();

    expect(
      stats(),
      const ScanStats(
        seen: 3,
        nomedia: 0,
        excluded: 1,
        tooSmall: 1,
        tooShort: 0,
        stored: 1,
      ),
    );
  });

  test('a short file is counted again when remembered, not read', () async {
    touch('a.mp3');
    touch('short.mp3');
    reader.durationByName['short.mp3'] = 5000;
    reader.durationByName['a.mp3'] = 60000;
    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(minDurationSeconds: 10));
    await scan();
    reader.reset();

    await scan();

    expect(reader.readCount, 0);
    expect(stats()!.tooShort, 1);
    expect(stats()!.seen, 2);
  });

  test('a stored track made too short by a new minimum is counted', () async {
    touch('a.mp3');
    reader.durationByName['a.mp3'] = 5000;
    await scan();
    expect(stats()!.tooShort, 0);

    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(minDurationSeconds: 10));
    reader.reset();
    await scan();

    expect(stats()!.tooShort, 1);
  });

  test('a scan that fails keeps the numbers of the one before', () async {
    touch('a.mp3');
    await scan();
    final before = stats();
    expect(before!.seen, 1);

    touch('b.mp3');
    reader.throwOnRead = StateError('boom');
    await scan();

    expect(stats(), before);
  });

  test('a folder that is gone keeps its rows out of both numbers', () async {
    touch('a.mp3');
    touch('b.mp3');
    await scan();
    expect(stats()!.stored, 2);
    expect(stats()!.unfinishedRoots, 0);

    Directory(root).renameSync('$root-away');
    await scan();

    expect(stats()!.seen, 0);
    expect(stats()!.stored, 0, reason: 'not the rows of the missing folder');
    expect(stats()!.unfinishedRoots, 1);
    expect(await db.storedTrackCount([1]), 2, reason: 'rows are kept');
  });

  test(
    'a file left out by another rule is not also counted as short',
    () async {
      touch('out/short.mp3');
      touch('a.mp3');
      reader.durationByName['out/short.mp3'] = 5000;
      reader.durationByName['short.mp3'] = 5000;
      reader.durationByName['a.mp3'] = 60000;
      await scan();

      container
          .read(settingsProvider.notifier)
          .setLibraryScan(const LibraryScanPrefs(minDurationSeconds: 10));
      await db.addExcludedFolder('$root/out', 1);
      reader.reset();
      await scan();

      expect(stats()!.excluded, 1);
      expect(stats()!.tooShort, 0);
    },
  );

  test('a short file deleted from the disk is not counted as short', () async {
    touch('a.mp3');
    touch('short.mp3');
    reader.durationByName['short.mp3'] = 5000;
    reader.durationByName['a.mp3'] = 60000;
    await scan();

    File('$root/short.mp3').deleteSync();
    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(minDurationSeconds: 10));
    reader.reset();
    await scan();

    expect(stats()!.seen, 1);
    expect(stats()!.tooShort, 0);
  });
}
