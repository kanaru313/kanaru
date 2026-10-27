import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'history_rows.dart';
import 'playlist_cover_keys.dart';
import 'library_database.dart';
import 'search_terms.dart';

export 'history_rows.dart';

// Every time bound is an epoch-ms half-open range `[start, end)` computed by
// the caller from local calendar dates (DST-safe); SQL never converts time.

/// The SQL strings are public only so the plan test can EXPLAIN them.

/// Plays per bucket between consecutive bounds (`json_each` of the bounds).
/// `plays_played_at` serves each range count.
@visibleForTesting
const historyBucketSql = '''
SELECT * FROM (
  WITH b(s, e) AS (SELECT value, lead(value) OVER (ORDER BY key) FROM json_each(?1))
  SELECT s AS day_start,
    (SELECT count(*) FROM plays WHERE played_at >= b.s AND played_at < b.e) AS n
  FROM b WHERE e IS NOT NULL
) WHERE n > 0 ORDER BY day_start DESC''';

/// Same shape as [historyBucketSql] plus the distinct songs of each bucket.
/// `plays_played_at (played_at, path)` covers both subqueries.
@visibleForTesting
const historyDayBucketSql = '''
SELECT * FROM (
  WITH b(s, e) AS (SELECT value, lead(value) OVER (ORDER BY key) FROM json_each(?1))
  SELECT s AS day_start,
    (SELECT count(*) FROM plays WHERE played_at >= b.s AND played_at < b.e) AS n,
    (SELECT count(DISTINCT path) FROM plays WHERE played_at >= b.s AND played_at < b.e) AS tracks
  FROM b WHERE e IS NOT NULL
) WHERE n > 0 ORDER BY day_start DESC''';

/// Plays and distinct songs in `[?1, ?2)`.
@visibleForTesting
const historyRangeSummarySql =
    'SELECT count(*) AS n, count(DISTINCT path) AS tracks FROM plays '
    'WHERE played_at >= ?1 AND played_at < ?2';

/// Cover keys of the latest plays, newest first. The inner query is bounded
/// (`?1` plays) so a library without covers is not walked whole; `CROSS JOIN`
/// keeps the plays side as the outer loop.
@visibleForTesting
const historyCoverKeysSql = '''
SELECT t.cover_key FROM (SELECT path, played_at FROM plays ORDER BY played_at DESC LIMIT ?1) p
CROSS JOIN tracks t ON t.path = p.path
WHERE t.cover_key IS NOT NULL ORDER BY p.played_at DESC''';

/// `nth` counts the plays of the same path after this one and subtracts them
/// from the total: recent days, the ones people open, have few later plays.
/// Two range subqueries (no OR) so each one is an index search.
@visibleForTesting
const historyDayPlaysSql = '''
SELECT p.id, p.path, p.played_at, p.listened_ms,
  s.play_count
    - (SELECT count(*) FROM plays q WHERE q.path = p.path AND q.played_at > p.played_at)
    - (SELECT count(*) FROM plays q WHERE q.path = p.path AND q.played_at = p.played_at AND q.id > p.id)
    AS nth,
  s.play_count,
  t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM plays p
LEFT JOIN play_stats s ON s.path = p.path
LEFT JOIN tracks t ON t.path = p.path
WHERE p.played_at >= ?1 AND p.played_at < ?2
ORDER BY p.played_at DESC, p.id DESC''';

/// Plays in `[?1, ?2)` of library songs the FTS query `?3` matches, newest
/// first, at most `?4`. Same row shape as [historyDayPlaysSql]; a play whose
/// file is not in the library has no song to match and never comes back.
@visibleForTesting
const historyPlaysMatchingSql = '''
SELECT p.id, p.path, p.played_at, p.listened_ms,
  s.play_count
    - (SELECT count(*) FROM plays q WHERE q.path = p.path AND q.played_at > p.played_at)
    - (SELECT count(*) FROM plays q WHERE q.path = p.path AND q.played_at = p.played_at AND q.id > p.id)
    AS nth,
  s.play_count,
  t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM plays p
LEFT JOIN play_stats s ON s.path = p.path
JOIN tracks t ON t.path = p.path
WHERE p.played_at >= ?1 AND p.played_at < ?2
  AND t.id IN (SELECT rowid FROM track_search WHERE track_search MATCH ?3)
ORDER BY p.played_at DESC, p.id DESC
LIMIT ?4''';

const _topColumns =
    'a.path, a.n, a.last, t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, '
    't.year, t.duration_ms, t.cover_key';

@visibleForTesting
const historyTopRangeSql =
    '''
SELECT $_topColumns
FROM (SELECT path, count(*) AS n, max(played_at) AS last FROM plays
      WHERE played_at >= ?1 AND played_at < ?2
      GROUP BY path ORDER BY n DESC, last ASC, path LIMIT ?3) a
LEFT JOIN tracks t ON t.path = a.path
ORDER BY a.n DESC, a.last ASC, a.path''';

@visibleForTesting
const historyTopAllSql =
    '''
SELECT $_topColumns
FROM (SELECT path, play_count AS n, last_played_at AS last FROM play_stats
      ORDER BY n DESC, last ASC, path LIMIT ?1) a
LEFT JOIN tracks t ON t.path = a.path
ORDER BY a.n DESC, a.last ASC, a.path''';

/// Listen history reads. All are one-shot; the provider layer decides when to
/// run them again. Writes are in `history_play_writes.dart`.
extension HistoryQueries on LibraryDatabase {
  /// Earliest and latest `played_at`, or null when there is no play.
  Future<({int first, int last})?> historyPlayedRange() async {
    final row = await customSelect(
      'SELECT min(played_at) AS lo, max(played_at) AS hi FROM plays',
      readsFrom: {plays},
    ).getSingle();
    final lo = row.readNullable<int>('lo');
    final hi = row.readNullable<int>('hi');
    return lo == null || hi == null ? null : (first: lo, last: hi);
  }

  /// Years in `[fromYear, toYear]` (local calendar) with at least one play,
  /// newest first.
  Future<List<int>> historyYears(int fromYear, int toYear) async {
    if (toYear < fromYear) return const [];
    final bounds = [
      for (var y = fromYear; y <= toYear + 1; y++)
        DateTime(y).millisecondsSinceEpoch,
    ];
    final rows = await customSelect(
      historyBucketSql,
      variables: [Variable.withString(jsonEncode(bounds))],
      readsFrom: {plays},
    ).get();
    return [
      for (final r in rows)
        DateTime.fromMillisecondsSinceEpoch(r.read<int>('day_start')).year,
    ];
  }

  /// Plays per bucket for the ascending [dayBounds] (bucket i is
  /// `[dayBounds[i], dayBounds[i+1])`), empty buckets dropped, newest first.
  /// Bucket lengths may differ (23 h and 25 h days).
  Future<List<HistoryDayCount>> historyDayCounts(List<int> dayBounds) async {
    if (dayBounds.length < 2) return const [];
    final rows = await customSelect(
      historyDayBucketSql,
      variables: [Variable.withString(jsonEncode(dayBounds))],
      readsFrom: {plays},
    ).get();
    return [
      for (final r in rows)
        HistoryDayCount(
          dayStart: r.read<int>('day_start'),
          count: r.read<int>('n'),
          tracks: r.read<int>('tracks'),
        ),
    ];
  }

  /// The start of every bucket of [dayBounds] (see [historyDayCounts]) that
  /// has at least one play: the days to put a dot on.
  Future<Set<int>> historyPlayDayStarts(List<int> dayBounds) async {
    if (dayBounds.length < 2) return const {};
    final rows = await customSelect(
      historyBucketSql,
      variables: [Variable.withString(jsonEncode(dayBounds))],
      readsFrom: {plays},
    ).get();
    return {for (final r in rows) r.read<int>('day_start')};
  }

  /// Plays and distinct songs started in `[start, end)`.
  Future<HistoryRangeSummary> historyRangeSummary(int start, int end) async {
    final row = await customSelect(
      historyRangeSummarySql,
      variables: [Variable.withInt(start), Variable.withInt(end)],
      readsFrom: {plays},
    ).getSingle();
    return (plays: row.read<int>('n'), tracks: row.read<int>('tracks'));
  }

  /// Totals over every play, the first play and the covers of the latest
  /// plays (the page collage).
  Future<HistoryOverview> historyOverview() => transaction(() async {
    final totals = await customSelect(
      'SELECT coalesce(sum(play_count), 0) AS n, count(*) AS tracks, '
      'min(first_played_at) AS first FROM play_stats',
      readsFrom: {playStats},
    ).getSingle();
    final keys = await customSelect(
      historyCoverKeysSql,
      variables: [Variable.withInt(playlistCollageEntryScanLimit)],
      readsFrom: {plays, tracks},
    ).get();
    return HistoryOverview(
      plays: totals.read<int>('n'),
      tracks: totals.read<int>('tracks'),
      firstPlayedAt: totals.readNullable<int>('first'),
      coverKeys: pickCollageKeys([
        for (final r in keys) r.readNullable<String>('cover_key'),
      ]),
    );
  });

  /// Every library song with a play, last played first. Reads all of
  /// `play_stats`, so call it on demand (a button press), not on every change.
  Future<List<TrackListItem>> historyPlayedTracks() async {
    final rows = await customSelect(
      '''
SELECT t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM play_stats s JOIN tracks t ON t.path = s.path
ORDER BY s.last_played_at DESC, s.path''',
      readsFrom: {playStats, tracks},
    ).get();
    return [for (final r in rows) _track(r)!];
  }

  /// Plays started in `[start, end)`, newest first (`played_at DESC, id
  /// DESC`), each with its "Nth listen" and library row.
  Future<List<HistoryPlayRow>> historyDayPlays(int start, int end) async {
    final rows = await customSelect(
      historyDayPlaysSql,
      variables: [Variable.withInt(start), Variable.withInt(end)],
      readsFrom: {plays, playStats, tracks},
    ).get();
    return [for (final r in rows) _playRow(r)];
  }

  /// Plays started in `[start, end)` of library songs that have every term as
  /// a word prefix of title, artist or album (the playlist filter rule),
  /// newest first, at most [limit]; `truncated` tells there were more. No
  /// terms, no plays.
  Future<({List<HistoryPlayRow> rows, bool truncated})> historyPlaysMatching(
    int start,
    int end,
    List<String> terms, {
    int limit = 1000,
  }) async {
    assert(limit > 0, 'limit must be positive');
    if (terms.isEmpty) {
      return (rows: const <HistoryPlayRow>[], truncated: false);
    }
    final read = await customSelect(
      historyPlaysMatchingSql,
      variables: [
        Variable.withInt(start),
        Variable.withInt(end),
        Variable.withString(
          '{title_sort artist_search album_search} : (${ftsPrefixQuery(terms)})',
        ),
        // One more than asked for tells whether the list was cut.
        Variable.withInt(limit + 1),
      ],
      readsFrom: {plays, playStats, tracks, trackSearch},
    ).get();
    return (
      rows: [for (final r in read.take(limit)) _playRow(r)],
      truncated: read.length > limit,
    );
  }

  /// Most played tracks, at most [limit]. Ties: the earlier last play inside
  /// the range first, then `path`. With no range ([start] and [end] both
  /// null) it reads `play_stats`; giving only one of them is an error.
  Future<List<HistoryTopRow>> historyTopPlays({
    int? start,
    int? end,
    required int limit,
  }) async {
    if ((start == null) != (end == null)) {
      throw ArgumentError('start and end must both be given or both be null');
    }
    final all = start == null;
    final rows = await customSelect(
      all ? historyTopAllSql : historyTopRangeSql,
      variables: [
        if (!all) ...[Variable.withInt(start), Variable.withInt(end!)],
        Variable.withInt(limit),
      ],
      readsFrom: {if (all) playStats else plays, tracks},
    ).get();
    return [
      for (final r in rows)
        HistoryTopRow(
          path: r.read<String>('path'),
          count: r.read<int>('n'),
          lastPlayedAt: r.read<int>('last'),
          track: _track(r),
        ),
    ];
  }

  /// Totals of one track from `play_stats` and its library row.
  Future<HistoryTrackSummary> historyTrackSummary(String path) async {
    final row = await customSelect(
      '''
SELECT s.play_count, s.first_played_at, s.last_played_at,
  t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM (SELECT ?1 AS path) k
LEFT JOIN play_stats s ON s.path = k.path
LEFT JOIN tracks t ON t.path = k.path''',
      variables: [Variable.withString(path)],
      readsFrom: {playStats, tracks},
    ).getSingle();
    return HistoryTrackSummary(
      path: path,
      track: _track(row),
      count: row.readNullable<int>('play_count') ?? 0,
      firstPlayedAt: row.readNullable<int>('first_played_at'),
      lastPlayedAt: row.readNullable<int>('last_played_at'),
    );
  }

  /// Every play of [path], newest first; `nth` counts down to 1. `track` is
  /// left null (the page takes it from [historyTrackSummary]).
  Future<List<HistoryPlayRow>> historyTrackPlays(String path) async {
    final rows = await customSelect(
      'SELECT id, played_at, listened_ms FROM plays WHERE path = ?1 '
      'ORDER BY played_at DESC, id DESC',
      variables: [Variable.withString(path)],
      readsFrom: {plays},
    ).get();
    return [
      for (var i = 0; i < rows.length; i++)
        HistoryPlayRow(
          id: rows[i].read<int>('id'),
          path: path,
          playedAt: rows[i].read<int>('played_at'),
          listenedMs: rows[i].readNullable<int>('listened_ms'),
          nth: rows.length - i,
          latest: i == 0,
        ),
    ];
  }
}

HistoryPlayRow _playRow(QueryRow r) => HistoryPlayRow(
  id: r.read<int>('id'),
  path: r.read<String>('path'),
  playedAt: r.read<int>('played_at'),
  listenedMs: r.readNullable<int>('listened_ms'),
  nth: r.readNullable<int>('nth'),
  latest: _isLatest(r),
  track: _track(r),
);

/// No later play of the same path: the Nth listen is the last one counted.
bool _isLatest(QueryRow r) {
  final nth = r.readNullable<int>('nth');
  return nth != null && nth == r.readNullable<int>('play_count');
}

// Same shape as the playlist reader's row mapper; that one is private to a
// file this lane does not own.
// The player URI comes from the `tracks` row, never from a plays path.
TrackListItem? _track(QueryRow row) {
  final trackId = row.readNullable<int>('track_id');
  if (trackId == null) return null;
  return TrackListItem(
    id: trackId,
    path: row.read<String>('track_path'),
    title: row.read<String>('title'),
    artist: row.readNullable<String>('artist'),
    album: row.readNullable<String>('album'),
    year: row.readNullable<int>('year'),
    durationMs: row.readNullable<int>('duration_ms'),
    coverKey: row.readNullable<String>('cover_key'),
  );
}
