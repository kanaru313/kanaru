import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/scan_stats_queries.dart';
import 'scan_totals.dart';
import 'walk_audio_files.dart' show WalkResult;

final _log = Logger('indexer');

/// What the last scan saw and left out, counted per reason. Only the scan
/// knows these (the files it left out are never stored), so they live for
/// the session, not in the database.
class ScanStats {
  const ScanStats({
    this.seen = 0,
    this.nomedia = 0,
    this.excluded = 0,
    this.tooSmall = 0,
    this.tooShort = 0,
    this.stored = 0,
    this.unfinishedRoots = 0,
  });

  /// The counts of one root: [walk] is its walk after the scan rules,
  /// [seen] the audio files the walk listed before them, and [tooShort] the
  /// files left out for their length (read now, or remembered as too short).
  factory ScanStats.ofRoot(
    WalkResult walk, {
    required int seen,
    required int tooShort,
  }) => ScanStats(
    seen: seen,
    nomedia: walk.nomediaOut,
    excluded: walk.excludedOut,
    tooSmall: walk.tooSmallOut,
    tooShort: tooShort,
  );

  /// Audio files the walks listed, before any rule.
  final int seen;

  /// Tracks stored for the roots this scan finished, counted when it ended:
  /// the same roots [seen] counts, so the two can be set side by side. 0 on
  /// the counts of one root; the indexer fills it in once for the scan.
  final int stored;

  /// Roots the scan did not finish (missing, timed out, empty or stuck);
  /// their files are in neither [seen] nor [stored].
  final int unfinishedRoots;

  /// These counts with the figures only the end of the scan knows.
  ScanStats withEnd({required int stored, required int unfinishedRoots}) =>
      ScanStats(
        seen: seen,
        nomedia: nomedia,
        excluded: excluded,
        tooSmall: tooSmall,
        tooShort: tooShort,
        stored: stored,
        unfinishedRoots: unfinishedRoots,
      );

  /// Files left out for being inside a folder with a `.nomedia`, inside a
  /// folder the user left out, under the minimum size, or under the minimum
  /// length.
  final int nomedia, excluded, tooSmall, tooShort;

  ScanStats operator +(ScanStats other) => ScanStats(
    seen: seen + other.seen,
    nomedia: nomedia + other.nomedia,
    excluded: excluded + other.excluded,
    tooSmall: tooSmall + other.tooSmall,
    tooShort: tooShort + other.tooShort,
    stored: stored + other.stored,
    unfinishedRoots: unfinishedRoots + other.unfinishedRoots,
  );

  @override
  bool operator ==(Object other) =>
      other is ScanStats &&
      seen == other.seen &&
      nomedia == other.nomedia &&
      excluded == other.excluded &&
      tooSmall == other.tooSmall &&
      tooShort == other.tooShort &&
      stored == other.stored &&
      unfinishedRoots == other.unfinishedRoots;

  @override
  int get hashCode => Object.hash(
    seen,
    nomedia,
    excluded,
    tooSmall,
    tooShort,
    stored,
    unfinishedRoots,
  );
}

/// The counts of the latest scan of this session that ended without error;
/// null until one has. Published by the indexer, shown in Settings.
class LastScanStats extends Notifier<ScanStats?> {
  @override
  ScanStats? build() => null;

  void publish(ScanStats stats) => state = stats;

  /// Publishes the counts of a scan that ended without error ([totals]),
  /// with the tracks now stored for the roots it finished, so "stored of
  /// seen" compares the same files. A failed count keeps the previous
  /// numbers rather than failing a scan that worked.
  Future<void> publishScan(LibraryDatabase db, ScanTotals totals) async {
    try {
      final stored = await db.storedTrackCount(totals.okRootIds);
      if (!ref.mounted) return;
      publish(
        totals.stats.withEnd(
          stored: stored,
          unfinishedRoots: totals.skipped.length,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning('Scan statistics not published', error, stackTrace);
    }
  }
}

final lastScanStatsProvider = NotifierProvider<LastScanStats, ScanStats?>(
  LastScanStats.new,
);
