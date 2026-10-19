/// Which step of a scan is running.
enum ScanPhase { discovering, reading }

/// Why a root was skipped without changes.
enum SkipReason { missing, empty }

/// Totals of a finished scan.
class ScanSummary {
  const ScanSummary({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.failedTags = 0,
    this.skippedRoots = const {},
  });

  final int added;
  final int updated;
  final int removed;

  /// Files stored without tags because reading them failed.
  final int failedTags;

  /// Roots left untouched: missing (unplugged, gone) or empty while the
  /// database has tracks for them. Keyed by root path.
  final Map<String, SkipReason> skippedRoots;
}

/// Progress of the library scan.
sealed class IndexerState {
  const IndexerState();
}

class IndexerIdle extends IndexerState {
  const IndexerIdle();
}

class IndexerScanning extends IndexerState {
  const IndexerScanning({
    required this.phase,
    required this.rootPath,
    this.done = 0,
    this.total = 0,
  });

  final ScanPhase phase;
  final String rootPath;

  /// Files read so far of [total] to read in this root; both 0 while
  /// discovering.
  final int done;
  final int total;
}

class IndexerFinished extends IndexerState {
  /// [at] defaults to now.
  IndexerFinished(this.summary, {DateTime? at}) : at = at ?? DateTime.now();

  final ScanSummary summary;

  /// When the scan ended, so a screen can tell a fresh result from an old
  /// one it only now gets to see.
  final DateTime at;
}

class IndexerFailed extends IndexerState {
  /// [at] defaults to now.
  IndexerFailed(this.message, {DateTime? at}) : at = at ?? DateTime.now();

  /// Technical detail for the log, not for display.
  final String message;

  /// When the scan failed; see [IndexerFinished.at].
  final DateTime at;
}
