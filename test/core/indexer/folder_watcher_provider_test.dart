import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/folder_watcher_provider.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/library_startup_tasks.dart';
import 'package:kanaru/core/indexer/scanned_folders.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_tag_reader.dart';
import 'fake_watch_env.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeDirWatch dirs;
  late FakeTagReader reader;
  late List<String> walked;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('folder_watcher_provider_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory('$root/a').createSync(recursive: true);
    File('$root/a/one.mp3').writeAsStringSync('x');
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots([root], now: 1);
    dirs = FakeDirWatch();
    reader = FakeTagReader();
    walked = [];
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ProviderContainer containerFor({
    bool watch = true,
    bool rescanOnStartup = true,
    bool hasDb = true,
    int budget = 100,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: hasDb ? db : null, hasRoots: true).overrides,
        tagReaderProvider.overrideWithValue(reader),
        dirWatchProvider.overrideWithValue(dirs.call),
        watchBudgetProvider.overrideWithValue(budget),
        rootWalkerProvider.overrideWithValue((path) {
          walked.add(path);
          return walkAudioFilesInIsolate(path);
        }),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            rescanOnStartup: rescanOnStartup,
            libraryScan: LibraryScanPrefs(watchFolders: watch),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> setWatch(ProviderContainer container, bool on) async {
    final settings = container.read(settingsProvider.notifier);
    settings.setLibraryScan(
      container.read(settingsProvider).libraryScan.copyWith(watchFolders: on),
    );
    container.read(folderWatcherProvider);
    await settle();
  }

  test('off: nothing is watched or listed', () async {
    final container = containerFor(watch: false);
    container.listen(folderWatcherProvider, (_, _) {});
    await settle();

    expect(container.read(folderWatcherProvider), WatchStatus.off);
    expect(dirs.opened, isEmpty);
    expect(walked, isEmpty);
  });

  test('without a database it stays off', () async {
    final container = containerFor(hasDb: false);
    container.listen(folderWatcherProvider, (_, _) {});
    await settle();

    expect(container.read(folderWatcherProvider), WatchStatus.off);
    expect(dirs.opened, isEmpty);
  });

  test('turned on before any scan: folders are listed, not scanned', () async {
    final container = containerFor(watch: false);
    container.listen(folderWatcherProvider, (_, _) {});
    await setWatch(container, true);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(folderWatcherProvider), WatchStatus.watching);
    expect(walked, [root]);
    expect(dirs.opened, unorderedEquals([root, '$root/a']));
    expect(await db.select(db.tracks).get(), isEmpty);
    expect(reader.readCount, 0);
  });

  test(
    'turned on after a scan: watches the published folders at once',
    () async {
      final container = containerFor(watch: false);
      container.listen(folderWatcherProvider, (_, _) {});
      await container.read(libraryIndexerProvider.notifier).scan();
      walked.clear();

      await setWatch(container, true);

      expect(walked, isEmpty);
      expect(dirs.opened, unorderedEquals([root, '$root/a']));
    },
  );

  test('turned off: every watch is cancelled', () async {
    final container = containerFor();
    container.listen(folderWatcherProvider, (_, _) {});
    await container.read(libraryIndexerProvider.notifier).scan();
    await settle();
    expect(dirs.hasListener(root), isTrue);

    await setWatch(container, false);

    expect(container.read(folderWatcherProvider), WatchStatus.off);
    expect(dirs.anyListener, isFalse);
  });

  test('a scan that ends later gives the folders to watch', () async {
    final container = containerFor();
    final scanning = container.read(libraryIndexerProvider.notifier).scan();
    container.listen(folderWatcherProvider, (_, _) {});
    await settle();
    expect(container.read(libraryIndexerProvider.notifier).isRunning, isTrue);
    await scanning;
    await settle();

    expect(dirs.opened, unorderedEquals([root, '$root/a']));
    // The indexer's own walk, not a second listing.
    expect(walked, [root]);
  });

  test(
    'more folders than the budget: limit reached, setting unchanged',
    () async {
      final container = containerFor(budget: 1);
      container.listen(folderWatcherProvider, (_, _) {});
      await container.read(libraryIndexerProvider.notifier).scan();
      await settle();

      expect(container.read(folderWatcherProvider), WatchStatus.limitReached);
      expect(dirs.opened, isEmpty);
      expect(container.read(settingsProvider).libraryScan.watchFolders, isTrue);

      // Off and on again tries afresh.
      await setWatch(container, false);
      await setWatch(container, true);
      expect(container.read(folderWatcherProvider), WatchStatus.limitReached);
    },
  );

  test(
    'startup without the startup scan lists and watches the folders',
    () async {
      final container = containerFor(rescanOnStartup: false);

      expect(runLibraryStartupTasks(container), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(dirs.opened, unorderedEquals([root, '$root/a']));
      expect(await db.select(db.tracks).get(), isEmpty);
      expect(reader.readCount, 0);
      expect(container.read(scannedFoldersProvider).byRoot, isNotEmpty);
    },
  );

  test(
    'startup with the startup scan lets that scan give the folders',
    () async {
      final container = containerFor();

      await runLibraryStartupTasks(container);
      await settle();

      expect(walked, [root], reason: 'one walk, the scan\'s');
      expect(dirs.opened, unorderedEquals([root, '$root/a']));
    },
  );
}
