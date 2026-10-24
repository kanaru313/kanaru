import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'history_rows.dart';
import 'library_database.dart';

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
  t.id AS track_id, t.path AS track_path, t.title, t.artist, t.album, t.year, t.duration_ms, t.cover_key
FROM plays p
LEFT JOIN play_stats s ON s.path = p.path
LEFT JOIN tracks t ON t.path = p.path
WHERE p.played_at >= ?1 AND p.played_at < ?2
ORDER BY p.played_at DESC, p.id DESC''';

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
    final counts = await _bucketCounts(bounds);
    return [
      for (final c in counts)
        DateTime.fromMillisecondsSinceEpoch(c.dayStart).year,
    ];
  }

  /// Plays per bucket for the ascending [dayBounds] (bucket i is
  /// `[dayBounds[i], dayBounds[i+1])`), empty buckets dropped, newest first.
  /// Bucket lengths may differ (23 h and 25 h days).
  Future<List<HistoryDayCount>> historyDayCounts(List<int> dayBounds) =>
      _bucketCounts(dayBounds);

  /// Plays started in `[start, end)`, newest first (`played_at DESC, id
  /// DESC`), each with its "Nth listen" and library row.
  Future<List<HistoryPlayRow>> historyDayPlays(int start, int end) async {
    final rows = await customSelect(
      historyDayPlaysSql,
      variables: [Variable.withInt(start), Variable.withInt(end)],
      readsFrom: {plays, playStats, tracks},
    ).get();
    return [
      for (final r in rows)
        HistoryPlayRow(
          id: r.read<int>('id'),
          path: r.read<String>('path'),
          playedAt: r.read<int>('played_at'),
          listenedMs: r.readNullable<int>('listened_ms'),
          nth: r.readNullable<int>('nth'),
          track: _track(r),
        ),
    ];
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
        ),
    ];
  }

  Future<List<HistoryDayCount>> _bucketCounts(List<int> bounds) async {
    if (bounds.length < 2) return const [];
    final rows = await customSelect(
      historyBucketSql,
      variables: [Variable.withString(jsonEncode(bounds))],
      readsFrom: {plays},
    ).get();
    return [
      for (final r in rows)
        HistoryDayCount(
          dayStart: r.read<int>('day_start'),
          count: r.read<int>('n'),
        ),
    ];
  }
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
