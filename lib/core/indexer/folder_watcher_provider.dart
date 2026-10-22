import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'folder_watcher.dart';
import 'indexer_providers.dart';
import 'indexer_state.dart';
import 'scanned_folders.dart';

export 'folder_watcher.dart' show WatchStatus;

final _log = Logger('folder_watcher');

/// Where Linux keeps the number of inotify watches a user may hold.
const _maxUserWatchesFile = '/proc/sys/fs/inotify/max_user_watches';

/// Used when the limit cannot be read (the kernel default of old kernels).
const _defaultMaxUserWatches = 8192;

/// A quarter of the user's inotify watches is all the library may take: the
/// budget is shared with the IDE, Syncthing and every other watcher.
int inotifyBudget({String file = _maxUserWatchesFile}) {
  var limit = _defaultMaxUserWatches;
  try {
    limit = int.tryParse(File(file).readAsStringSync().trim()) ?? limit;
  } on FileSystemException {
    // Not Linux, or /proc is hidden: assume the default.
  }
  return limit ~/ 4;
}

/// Watches one folder with inotify; tests override it with a fake.
final dirWatchProvider = Provider<DirWatch>(
  (ref) =>
      (dir) => Directory(dir).watch(),
);

/// How many folders may be watched; tests override it.
final watchBudgetProvider = Provider<int>((ref) => inotifyBudget());

/// Keeps the library up to date while the app runs: with "Watch folders" on
/// and a library database, it watches the folders the last scan saw and asks
/// the indexer for a quiet scan of the changes. State: [WatchStatus]. Turning
/// the setting off, or losing the database, drops every watch and timer.
final folderWatcherProvider =
    NotifierProvider<FolderWatcherController, WatchStatus>(
      FolderWatcherController.new,
    );

class FolderWatcherController extends Notifier<WatchStatus> {
  /// The folders were listed once for this watcher; a second try on an empty
  /// answer would loop (an empty answer publishes, which listens again).
  bool _listed = false;

  @override
  WatchStatus build() {
    final enabled = ref.watch(
      settingsProvider.select((s) => s.libraryScan.watchFolders),
    );
    final db = ref.watch(libraryDatabaseProvider);
    if (!enabled || db == null) return WatchStatus.off;

    _listed = false;
    late final FolderWatcher watcher;
    watcher = FolderWatcher(
      watch: ref.read(dirWatchProvider),
      maxWatches: ref.read(watchBudgetProvider),
      onChange: () => unawaited(_scanChanges(watcher)),
    );
    final statuses = watcher.statusChanges.listen((next) {
      if (ref.mounted) state = next;
    });
    ref.onDispose(() {
      unawaited(statuses.cancel());
      unawaited(watcher.dispose());
    });
    ref.listen(scannedFoldersProvider, (_, next) {
      watcher.sync(next.byRoot.values.expand((dirs) => dirs));
      if (next.byRoot.isEmpty) unawaited(_listWithoutScan());
    }, fireImmediately: true);
    return watcher.status;
  }

  Future<void> _scanChanges(FolderWatcher watcher) async {
    try {
      await ref.read(libraryIndexerProvider.notifier).scanForChanges();
    } catch (error, stackTrace) {
      _log.warning('Scan for changes failed', error, stackTrace);
      if (ref.mounted) watcher.scanEnded(failed: true, deferred: 0);
      return;
    }
    if (!ref.mounted) return;
    final failed = ref.read(libraryIndexerProvider) is IndexerFailed;
    watcher.scanEnded(
      failed: failed,
      // A scan that failed may have died before it published: the count
      // left there belongs to an earlier scan.
      deferred: failed ? 0 : ref.read(scannedFoldersProvider).deferred,
    );
  }

  /// No scan has told the folders yet. When the indexer is running, its
  /// result will; else (the app does not scan at start) list them once,
  /// leaving the tracks alone. A scan that publishes meanwhile wins.
  Future<void> _listWithoutScan() async {
    if (_listed || ref.read(libraryIndexerProvider.notifier).isRunning) return;
    _listed = true;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final before = ref.read(scannedFoldersProvider);
    try {
      final byRoot = await listLibraryFolders(
        db: db,
        walk: ref.read(rootWalkerProvider),
        prefs: ref.read(settingsProvider).libraryScan,
        timeout: ref.read(scanTimeoutsProvider).walk,
      );
      if (!ref.mounted ||
          !identical(ref.read(scannedFoldersProvider), before)) {
        return;
      }
      ref.read(scannedFoldersProvider.notifier).publish(byRoot);
    } catch (error, stackTrace) {
      _log.warning('Could not list the folders to watch', error, stackTrace);
    }
  }
}
