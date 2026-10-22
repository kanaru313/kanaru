import 'indexer_state.dart';

/// What scanning one library root produced: counts to add to the scan totals,
/// and why the root was left unfinished, if it was.
class RootScanResult {
  const RootScanResult({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.filtered = 0,
    this.failedTags = 0,
    this.undecodableNames = 0,
    this.undecodableSampleDirs = const [],
    this.skippedFolderNames = const [],
    this.skipReason,
    this.error,
    this.walkTime = Duration.zero,
    this.tagTime = Duration.zero,
    this.dbTime = Duration.zero,
  });

  /// A root that could not be scanned because [error] was thrown. Whatever
  /// batches were written before stay written.
  RootScanResult.failed(
    Object this.error, {
    this.walkTime = Duration.zero,
    this.tagTime = Duration.zero,
    this.dbTime = Duration.zero,
  }) : added = 0,
       updated = 0,
       removed = 0,
       filtered = 0,
       failedTags = 0,
       undecodableNames = 0,
       undecodableSampleDirs = const [],
       skippedFolderNames = const [],
       skipReason = null;

  final int added;
  final int updated;
  final int removed;

  /// Files and folders the scan rules left out of this root's walk.
  final int filtered;
  final int failedTags;

  /// Audio files and folders of this root skipped for a name that is not
  /// valid UTF-8,
  /// and a few folders holding them.
  final int undecodableNames;
  final List<String> undecodableSampleDirs;

  /// Names of the folders the walk left out (trash, hidden).
  final List<String> skippedFolderNames;

  /// Set when the root was left unchanged or unfinished (shown in the
  /// summary); null when it was scanned completely or [error] is set.
  final SkipReason? skipReason;

  /// Unexpected failure while scanning this root; null otherwise.
  final Object? error;

  final Duration walkTime;
  final Duration tagTime;
  final Duration dbTime;
}

/// How long one root may take before the indexer gives up on it.
class ScanTimeouts {
  const ScanTimeouts({
    this.walk = const Duration(seconds: 60),
    this.tagBatch = const Duration(seconds: 60),
  });

  /// For the walk of one root.
  final Duration walk;

  /// For reading the tags, or the covers, of one batch.
  final Duration tagBatch;
}
