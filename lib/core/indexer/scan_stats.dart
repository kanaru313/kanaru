import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'walk_audio_files.dart' show WalkResult;

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
  );

  @override
  bool operator ==(Object other) =>
      other is ScanStats &&
      seen == other.seen &&
      nomedia == other.nomedia &&
      excluded == other.excluded &&
      tooSmall == other.tooSmall &&
      tooShort == other.tooShort;

  @override
  int get hashCode => Object.hash(seen, nomedia, excluded, tooSmall, tooShort);
}

/// The counts of the latest scan of this session that ended without error;
/// null until one has. Published by the indexer, shown in Settings.
class LastScanStats extends Notifier<ScanStats?> {
  @override
  ScanStats? build() => null;

  void publish(ScanStats stats) => state = stats;
}

final lastScanStatsProvider = NotifierProvider<LastScanStats, ScanStats?>(
  LastScanStats.new,
);
