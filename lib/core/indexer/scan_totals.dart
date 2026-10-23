import 'indexer_state.dart';
import 'root_scan_result.dart';
import 'scan_stats.dart';
import 'scanned_folders.dart';
import 'walk_audio_files.dart' show maxUndecodableSamples;

/// The totals of one scan, summed over the results of its roots.
class ScanTotals {
  ScanTotals(Map<String, List<String>> previousFolders)
    : folders = ScannedFoldersTally(previousFolders);

  /// The folders the roots brought, for the folder watcher.
  final ScannedFoldersTally folders;

  int added = 0, updated = 0, removed = 0, failedTags = 0, filtered = 0;
  int undecodableNames = 0;

  /// What the roots saw and left out, by reason.
  ScanStats stats = const ScanStats();
  final undecodableDirs = <String>[];
  final skippedFolderNames = <String>{};
  final skipped = <String, SkipReason>{};

  /// Roots scanned to the end, without error: their covers are made next.
  final okRootIds = <int>[];
  Duration walkTime = Duration.zero,
      tagTime = Duration.zero,
      dbTime = Duration.zero;

  void add(int rootId, String rootPath, RootScanResult result) {
    added += result.added;
    updated += result.updated;
    removed += result.removed;
    filtered += result.filtered;
    stats += result.stats;
    failedTags += result.failedTags;
    undecodableNames += result.undecodableNames;
    skippedFolderNames.addAll(result.skippedFolderNames);
    for (final dir in result.undecodableSampleDirs) {
      if (undecodableDirs.length < maxUndecodableSamples) {
        undecodableDirs.add(dir);
      }
    }
    folders.add(rootPath, result);
    walkTime += result.walkTime;
    tagTime += result.tagTime;
    dbTime += result.dbTime;
    final reason = result.skipReason;
    if (reason != null) skipped[rootPath] = reason;
    if (reason == null && result.error == null) okRootIds.add(rootId);
  }
}
