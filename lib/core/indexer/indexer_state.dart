/// Which step of a scan is running.
enum ScanPhase { discovering, reading }

/// Why a root was skipped or left unfinished.
enum SkipReason {
  /// Unplugged, gone or not listable; left unchanged.
  missing,

  /// No audio files while the database has tracks for it; left unchanged.
  empty,

  /// The walk or a tag read took too long; the batches written before stay.
  timedOut,

  /// An earlier tag read this session never returned, so the tag reader is
  /// not called again; the root is left unchanged.
  readerStuck,
}

/// Totals of a finished scan.
class ScanSummary {
  const ScanSummary({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.failedTags = 0,
    this.undecodableNames = 0,
    this.undecodableSampleDirs = const [],
    this.skippedRoots = const {},
  });

  final int added;
  final int updated;
  final int removed;

  /// Files stored without tags because reading them failed.
  final int failedTags;

  /// Audio files and folders skipped because their name is not valid UTF-8;
  /// their stored rows are kept.
  final int undecodableNames;

  /// A few folders holding such entries, for the log.
  final List<String> undecodableSampleDirs;

  /// Roots left untouched or unfinished, with the reason. Keyed by root path.
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

  /// Share of this root's files read so far (above 0, up to 1) while tags
  /// are read; `null` while files are still being looked for, when the
  /// amount of work is not known yet, and until the first batch is read:
  /// a ring at 0 draws nothing, while `null` keeps it spinning.
  double? get progress =>
      phase == ScanPhase.reading && done > 0 && total > 0 ? done / total : null;
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
