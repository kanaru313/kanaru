import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/excluded_folder_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/root_scan_result.dart';
import 'package:kanaru/core/indexer/scanned_folders.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;
  var missing = false, hang = false;
  var published = 0;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('scanned_folders_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader();
    missing = hang = false;
    published = 0;
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(reader),
        scanTimeoutsProvider.overrideWithValue(
          const ScanTimeouts(
            walk: Duration(milliseconds: 100),
            tagBatch: Duration(milliseconds: 100),
          ),
        ),
        rootWalkerProvider.overrideWithValue((path) {
          if (missing) return Future.value(const WalkResult(rootMissing: true));
          if (hang) return Completer<WalkResult>().future;
          return walkAudioFilesInIsolate(path);
        }),
      ],
    );
    container.listen(scannedFoldersProvider, (_, _) => published++);
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
  Map<String, List<String>> folders() =>
      container.read(scannedFoldersProvider).byRoot;

  test(
    'a scan publishes the folders it walked, hidden ones left out',
    () async {
      touch('a/one.mp3');
      touch('a/deep/two.mp3');
      touch('.cache/x.mp3');
      await scan();

      expect(
        folders()[root],
        unorderedEquals([root, '$root/a', '$root/a/deep']),
      );
    },
  );

  test('excluded folders are not published', () async {
    touch('a/one.mp3');
    touch('skip/two.mp3');
    await db.addExcludedFolder('$root/skip', 1);
    await scan();

    expect(folders()[root], unorderedEquals([root, '$root/a']));
  });

  test('a root that is gone loses its folders', () async {
    touch('a/one.mp3');
    await scan();
    expect(folders(), isNotEmpty);

    missing = true;
    await scan();
    expect(folders(), isEmpty);
    expect(published, 2);
  });

  test('a walk that times out keeps the folders known before', () async {
    touch('a/one.mp3');
    await scan();
    final before = folders();

    hang = true;
    await scan();
    expect(folders(), before);
    expect(published, 2);
  });

  test('an empty answer still replaces the folders', () async {
    touch('a/one.mp3');
    await scan();
    File('$root/a/one.mp3').deleteSync();
    touch('b/other.txt');
    await scan();

    expect(folders()[root], unorderedEquals([root, '$root/a', '$root/b']));
  });

  test('a root whose scan throws is still published, folders kept', () async {
    touch('a/one.mp3');
    await scan();
    touch('a/two.mp3');
    reader.throwOnRead = StateError('boom');
    await scan();

    expect(published, 2);
    expect(folders()[root], contains('$root/a'));
  });

  test('a root removed from the library is dropped', () async {
    touch('a/one.mp3');
    await scan();
    final id = (await db.roots()).single.id;
    await db.removeRoot(id);
    await scan();

    expect(folders(), isEmpty);
  });

  group('listLibraryFolders', () {
    Future<Map<String, List<String>>> list({
      LibraryScanPrefs prefs = const LibraryScanPrefs(),
    }) => listLibraryFolders(
      db: db,
      walk: walkAudioFilesInIsolate,
      prefs: prefs,
      timeout: const Duration(seconds: 5),
    );

    test('lists folders under the rules and touches no track', () async {
      touch('a/one.mp3');
      touch('skip/two.mp3');
      touch('nm/three.mp3');
      touch('nm/.nomedia');
      await db.addExcludedFolder('$root/skip', 1);

      final byRoot = await list(
        prefs: const LibraryScanPrefs(respectNomedia: true),
      );

      expect(byRoot[root], unorderedEquals([root, '$root/a']));
      expect(await db.select(db.tracks).get(), isEmpty);
      expect(reader.readCount, 0);
    });

    test('a missing root has no folders', () async {
      Directory(root).deleteSync(recursive: true);
      expect(await list(), isEmpty);
    });
  });
}
