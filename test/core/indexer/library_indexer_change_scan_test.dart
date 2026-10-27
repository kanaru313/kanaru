import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_indexer.dart';
import 'package:kanaru/core/indexer/scanned_folders.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

import '../database/songs_reference_query.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late String covers;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;
  var walks = 0;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_change_scan_test');
    final base = tmp.resolveSymbolicLinksSync();
    root = '$base/music';
    covers = '$base/cache/covers/512';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader()..coverDirectory = covers;
    walks = 0;
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db, coverCacheDirectory: covers).overrides,
        tagReaderProvider.overrideWithValue(reader),
        rootWalkerProvider.overrideWithValue((
          root, {
          required skipHiddenFolders,
        }) {
          walks++;
          return walkAudioFilesInIsolate(
            root,
            skipHiddenFolders: skipHiddenFolders,
          );
        }),
      ],
    );
    await db.addRoots([root], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File touch(String rel, {bool settled = true}) {
    final file = File('$root/$rel')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    if (settled) {
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    }
    return file;
  }

  LibraryIndexer indexer() => container.read(libraryIndexerProvider.notifier);
  Future<void> changes() => indexer().scanForChanges();
  Future<Set<String>> stored() async => {
    for (final t in await db.songs()) t.path.substring(root.length + 1),
  };

  test('a change scan is quiet and reads settled files', () async {
    touch('a.mp3');
    await changes();

    final state = container.read(libraryIndexerProvider) as IndexerFinished;
    expect(state.quiet, isTrue);
    expect(state.summary.added, 1);
    expect(await stored(), {'a.mp3'});
  });

  test(
    'a file changed in the last seconds is neither read nor stored',
    () async {
      touch('a.mp3');
      touch('b.mp3', settled: false);
      await changes();

      expect(await stored(), {'a.mp3'});
      expect(reader.readCount, 1);
      expect(container.read(scannedFoldersProvider).deferred, 1);

      // Once it is old enough, the next pass takes it.
      touch('b.mp3');
      await changes();
      expect(await stored(), {'a.mp3', 'b.mp3'});
      expect(container.read(scannedFoldersProvider).deferred, 0);
    },
  );

  test('a file dated far ahead is read and leaves nothing deferred', () async {
    touch('a.mp3')
        .setLastModifiedSync(DateTime.now().add(const Duration(hours: 3)));
    await changes();

    expect(await stored(), {'a.mp3'});
    expect(
      container.read(scannedFoldersProvider).deferred,
      0,
      reason: 'a deferral would make the watcher rescan again and again',
    );
  });

  test('a change scan queued behind a loud one is quiet', () async {
    touch('a.mp3');
    final loud = indexer().scan();
    final follow = changes();
    await Future.wait([loud, follow]);

    expect(
      (container.read(libraryIndexerProvider) as IndexerFinished).quiet,
      isTrue,
    );
  });

  test(
    'a stored file rewritten just now keeps its row and is not read',
    () async {
      final a = touch('a.mp3');
      await changes();
      reader.reset();

      a.writeAsStringSync('longer content'); // mtime is now, size differs
      await changes();

      expect(await stored(), {'a.mp3'});
      expect(reader.readCount, 0);
      expect(container.read(scannedFoldersProvider).deferred, 1);
    },
  );

  test('a scan the user asks for has no settle window', () async {
    touch('a.mp3', settled: false);
    await indexer().scan();

    expect(await stored(), {'a.mp3'});
    expect(container.read(scannedFoldersProvider).deferred, 0);
  });

  test(
    'covers that failed stay skipped in a change scan, not in a scan',
    () async {
      reader.failingCovers.add('a.mp3');
      touch('a.mp3');
      await indexer().scan();
      expect(reader.coverCount, 1);

      await changes();
      expect(reader.coverCount, 1, reason: 'skip set is kept');

      await indexer().scan();
      expect(reader.coverCount, 2, reason: 'a scan tries them again');
    },
  );

  test('asked while scanning, it adds one pass after the cover pass', () async {
    reader.hangingCovers.add('a.mp3');
    touch('a.mp3');
    final first = indexer().scan();
    // Walk and tags are done once the cover batch is waiting.
    while (reader.coverCount == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(indexer().isRunning, isTrue);
    touch('b.mp3');
    final follow = changes();
    expect(walks, 1);

    reader.releaseHangingCovers();
    await Future.wait([first, follow]);

    expect(walks, 2);
    expect(await stored(), {'a.mp3', 'b.mp3'});
    expect(indexer().isRunning, isFalse);
  });
}
