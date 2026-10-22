import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_database.dart';
import '../database/excluded_folder_queries.dart';
import '../settings/library_scan_prefs.dart';
import 'root_scan_result.dart';
import 'scan_rules.dart';
import 'walk_audio_files.dart';

/// How recently a file may have changed and still count as being written:
/// a scan for file changes leaves such files for the next pass.
const settleWindow = Duration(seconds: 2);

/// How far ahead of the scan's start a modification time may be and still
/// count as "being written now" (clock rounding between file system and
/// host). A file dated later is read, not deferred.
const settleClockSlack = Duration(seconds: 5);

/// The folders the library holds, as the last scan (or listing) saw them.
typedef ScannedFoldersState = ({
  Map<String, List<String>> byRoot,
  int deferred,
});

/// The folders of each root that passed the scan rules (excluded and
/// `.nomedia` folders are not in them), published once per scan. The folder
/// watcher watches exactly these. `deferred` counts files the last scan left
/// unread because they were still being written.
class ScannedFolders extends Notifier<ScannedFoldersState> {
  @override
  ScannedFoldersState build() => (byRoot: const {}, deferred: 0);

  /// Replaces the folders. Always a new value, so listeners run even when
  /// nothing changed: the watcher then starts a fresh round.
  void publish(Map<String, List<String>> byRoot, {int deferred = 0}) {
    state = (byRoot: Map.unmodifiable(byRoot), deferred: deferred);
  }
}

final scannedFoldersProvider =
    NotifierProvider<ScannedFolders, ScannedFoldersState>(ScannedFolders.new);

/// Builds the next [ScannedFoldersState] while a scan goes through its
/// roots. A root that was scanned, found empty or left for a stuck reader
/// brings its new folders; a root that is gone brings none; a root whose
/// walk gave no answer keeps the folders [previous] knew.
class ScannedFoldersTally {
  ScannedFoldersTally(this._previous);

  final Map<String, List<String>> _previous;
  final Map<String, List<String>> byRoot = {};
  int deferred = 0;

  void add(String rootPath, RootScanResult result) {
    deferred += result.deferred;
    final dirs = result.dirs ?? _previous[rootPath];
    if (dirs != null && dirs.isNotEmpty) byRoot[rootPath] = dirs;
  }
}

/// Lists the folders of every root without scanning: walks each root and
/// applies the rules, touching no track. For the folder watcher when the app
/// does not scan at start. A root that cannot be walked in [timeout] or is
/// missing has no folders.
Future<Map<String, List<String>>> listLibraryFolders({
  required LibraryDatabase db,
  required Future<WalkResult> Function(String root) walk,
  required LibraryScanPrefs prefs,
  required Duration timeout,
}) async {
  final rules = ScanRules.from(prefs, excluded: await db.excludedFolderPaths());
  final byRoot = <String, List<String>>{};
  for (final root in await db.roots()) {
    try {
      final result = applyWalkRules(
        await walk(root.path).timeout(timeout),
        root.path,
        rules.walk,
      );
      if (!result.rootMissing && result.dirs.isNotEmpty) {
        byRoot[root.path] = result.dirs;
      }
    } catch (_) {
      // A root that fails to list is left unwatched until the next scan.
    }
  }
  return byRoot;
}
