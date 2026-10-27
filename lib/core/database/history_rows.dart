import 'library_rows.dart';

/// Plays counted in one local day; [dayStart] is the bucket's inclusive
/// start, epoch ms, as the caller passed it.
class HistoryDayCount {
  const HistoryDayCount({
    required this.dayStart,
    required this.count,
    required this.tracks,
  });

  final int dayStart;
  final int count;

  /// Distinct songs played that day (a song played twice counts once).
  final int tracks;
}

/// Plays and distinct songs inside one time range.
typedef HistoryRangeSummary = ({int plays, int tracks});

/// What the History page shows about the whole history.
class HistoryOverview {
  const HistoryOverview({
    required this.plays,
    required this.tracks,
    required this.firstPlayedAt,
    required this.coverKeys,
  });

  /// Every play kept.
  final int plays;

  /// Distinct songs with at least one play.
  final int tracks;

  /// Earliest play, epoch ms; null when there is no play.
  final int? firstPlayedAt;

  /// Distinct cover keys of the latest plays, newest first, at most 4.
  final List<String> coverKeys;
}

/// One play in the journal or on a track's history page.
class HistoryPlayRow {
  const HistoryPlayRow({
    required this.id,
    required this.path,
    required this.playedAt,
    this.listenedMs,
    this.nth,
    this.latest = false,
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

  /// The newest play of [path] (no later play of it anywhere); false when
  /// the track has no `play_stats` row.
  final bool latest;

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
