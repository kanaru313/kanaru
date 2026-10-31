import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/extra_tags.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';

import '../database/songs_reference_query.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('extra_tags_backfill');
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

  void touch(String rel) => File('$root/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  ScanSummary summary() =>
      (container.read(libraryIndexerProvider) as IndexerFinished).summary;

  Future<Map<String, Map<String, Object?>>> rows() async => {
    for (final r
        in await db
            .customSelect(
              'SELECT path, extra_tags, cover_scan_version, updated_at, keys_version '
              'FROM tracks',
            )
            .get())
      r.read<String>('path').split('/').last: r.data,
  };

  /// Makes every stored row look like one scanned before the column existed,
  /// with cover and timestamps a full upsert would reset.
  Future<void> ageRows() => db.customStatement(
    'UPDATE tracks SET extra_tags = NULL, cover_scan_version = 7, '
    'updated_at = 12345',
  );

  test('a fresh scan stores the release date and a dateless {"v":1}', () async {
    touch('a.mp3');
    touch('b.mp3');
    reader.releaseDateByName['a.mp3'] = '2019-07-15';

    await scan();

    final stored = await rows();
    expect(
      decodeExtraTags(stored['a.mp3']!['extra_tags'] as String?).releaseDate,
      '2019-07-15',
    );
    expect(stored['b.mp3']!['extra_tags'], '{"v":$extraTagsVersion}');
  });

  test('unchanged files get extra tags without a full upsert', () async {
    touch('a.mp3');
    touch('b.mp3');
    await scan();
    await ageRows();
    reader.releaseDateByName['a.mp3'] = '20190715';
    reader.reset();

    await scan();

    expect(reader.batches.expand((b) => b).toSet(), {
      '$root/a.mp3',
      '$root/b.mp3',
    });
    final stored = await rows();
    expect(
      decodeExtraTags(stored['a.mp3']!['extra_tags'] as String?).releaseDate,
      '20190715',
    );
    expect(stored['b.mp3']!['extra_tags'], '{"v":$extraTagsVersion}');
    for (final row in stored.values) {
      expect(row['cover_scan_version'], 7, reason: 'cover pass not redone');
      expect(row['updated_at'], 12345);
    }
    expect(summary().added, 0);
    expect(summary().updated, 0);
    expect(summary().failedTags, 0);

    reader.reset();
    await scan();
    expect(reader.readCount, 0, reason: 'filled rows are not read again');
  });

  test('a row with an older version is read again once', () async {
    touch('a.mp3');
    await scan();
    await db.customStatement('UPDATE tracks SET extra_tags = \'{"v":0}\'');
    reader.reset();

    await scan();

    expect(reader.readCount, 1);
    expect((await rows())['a.mp3']!['extra_tags'], '{"v":$extraTagsVersion}');
  });

  test('a failed read keeps NULL and is tried again', () async {
    touch('a.mp3');
    await scan();
    await ageRows();
    reader.failingReads.add('a.mp3');
    reader.reset();

    await scan();

    final failed = (await rows())['a.mp3']!;
    expect(failed['extra_tags'], isNull);
    expect(failed['cover_scan_version'], 7);
    expect(failed['updated_at'], 12345);

    reader.failingReads.clear();
    reader.reset();
    await scan();
    expect((await rows())['a.mp3']!['extra_tags'], '{"v":$extraTagsVersion}');
  });

  test(
    'a file changed since the read is not written by the extra pass',
    () async {
      touch('a.mp3');
      await scan();
      await ageRows();
      final id = (await db.songs()).single.id;

      final written = await db.updateExtraTags([
        ExtraTagsUpdate(id: id, mtimeMs: -1, sizeBytes: -1, json: '{"v":1}'),
      ]);

      expect(written, 0);
      expect((await rows())['a.mp3']!['extra_tags'], isNull);
    },
  );

  test(
    'a file with a permanent scan error is not read again for extras',
    () async {
      touch('bad.mp3');
      await scan();
      reader.reset();

      await scan();

      expect(reader.readCount, 0);
    },
  );

  test(
    'a now-permanent error stores {"v":1} so it is not read again',
    () async {
      touch('a.mp3');
      await scan();
      await ageRows();
      reader.permanentReads.add('a.mp3');

      await scan();
      expect((await rows())['a.mp3']!['extra_tags'], '{"v":$extraTagsVersion}');

      reader.reset();
      await scan();
      expect(reader.readCount, 0);
    },
  );
}
