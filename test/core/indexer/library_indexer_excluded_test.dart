import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
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
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_excluded_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(FakeTagReader()),
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
  Future<Set<String>> stored() async => {
    for (final t in await db.songs()) t.path.substring(root.length + 1),
  };
  Future<int> exclude(String rel) async {
    await db.addExcludedFolder('$root/$rel', 1);
    return (await db.select(db.excludedFolders).get())
        .firstWhere((e) => e.path == '$root/$rel')
        .id;
  }

  test(
    'excluding a folder removes its tracks, lifting it brings them back',
    () async {
      touch('a/one.mp3');
      touch('a/deep/two.mp3');
      touch('ab/three.mp3');
      touch('top.mp3');
      await scan();
      expect(await stored(), hasLength(4));

      final id = await exclude('a');
      await scan();

      expect(await stored(), {'ab/three.mp3', 'top.mp3'});
      expect(
        (container.read(
          libraryIndexerProvider,
        ) as IndexerFinished).summary.removed,
        2,
      );

      await db.removeExcludedFolder(id);
      await scan();

      expect(await stored(), {
        'a/one.mp3',
        'a/deep/two.mp3',
        'ab/three.mp3',
        'top.mp3',
      });
    },
  );

  test('an exclusion holding every track empties the library', () async {
    touch('a/one.mp3');
    touch('a/two.mp3');
    await scan();

    await exclude('a');
    await scan();

    expect(await stored(), isEmpty);
    expect(container.read(libraryIndexerProvider), isA<IndexerFinished>());
  });

  test('an exclusion outside every root changes nothing', () async {
    touch('a/one.mp3');
    await db.addExcludedFolder('${tmp.path}/elsewhere', 1);

    await scan();

    expect(await stored(), {'a/one.mp3'});
  });

  test(
    'a failed read of the exclusions fails the scan and keeps the library',
    () async {
      touch('a/one.mp3');
      touch('b/two.mp3');
      await scan();
      await exclude('a');
      // Reads of the list now fail.
      await db.customStatement('DROP TABLE excluded_folders');

      await scan();

      expect(container.read(libraryIndexerProvider), isA<IndexerFailed>());
      expect(await stored(), {'a/one.mp3', 'b/two.mp3'});
    },
  );
}
