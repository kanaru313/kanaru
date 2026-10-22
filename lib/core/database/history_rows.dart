import 'library_rows.dart';

/// Plays counted in one time bucket (a local day or year); [dayStart] is the
/// bucket's inclusive start, epoch ms, as the caller passed it.
class HistoryDayCount {
  const HistoryDayCount({required this.dayStart, required this.count});

  final int dayStart;
  final int count;
}

/// One play in the journal or on a track's history page.
class HistoryPlayRow {
  const HistoryPlayRow({
    required this.id,
    required this.path,
    required this.playedAt,
    this.listenedMs,
    this.nth,
    this.track,
  });

  /// `plays.id`; the identity of the row (the same track repeats).
  final int id;

  /// Canonical `tracks.path` spelling, kept when the track is gone.
  final String path;

  /// When playback started, epoch ms.
  final int playedAt;

  /// Null means unknown, not 0.
  final int? listenedMs;

  /// "Nth listen of this track" in `(played_at, id)` order; null when the
  /// track has no `play_stats` row (the UI hides the badge).
  final int? nth;

  /// Null when no library track has [path] any more.
  final TrackListItem? track;
}

/// One entry of a most-played list.
class HistoryTopRow {
  const HistoryTopRow({
    required this.path,
    required this.count,
    required this.lastPlayedAt,
    this.track,
  });

  final String path;
  final int count;

  /// Latest play inside the queried range (all time when there is none).
  final int lastPlayedAt;

  /// Null when no library track has [path] any more.
  final TrackListItem? track;
}

/// Totals for one track. [count] is 0 and the times are null when the track
/// has no play left.
class HistoryTrackSummary {
  const HistoryTrackSummary({
    required this.path,
    required this.count,
    this.track,
    this.firstPlayedAt,
    this.lastPlayedAt,
  });

  final String path;
  final TrackListItem? track;
  final int count;
  final int? firstPlayedAt;
  final int? lastPlayedAt;
}
