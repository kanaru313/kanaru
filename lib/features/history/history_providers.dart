import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';
import 'history_days.dart';
import 'history_error_log.dart';
import 'history_plays_version.dart';
import 'history_range.dart' show historyTopLimit;
import 'history_tracks_version.dart';

/// Reads are not retried by Riverpod's default back-off: a failed read shows
/// the error, and the next change to the plays reads again.
Duration? _noRetry(int count, Object error) => null;

/// Years with at least one play, newest first. Empty without a library.
final historyYearsProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final db = ref.watch(libraryDatabaseProvider);
  ref.watch(historyPlaysVersionProvider);
  if (db == null) return const [];
  try {
    final range = await db.historyPlayedRange();
    if (range == null) return const [];
    return await db.historyYears(
      DateTime.fromMillisecondsSinceEpoch(range.first).year,
      DateTime.fromMillisecondsSinceEpoch(range.last).year,
    );
  } on Object catch (error) {
    logHistoryError('Reading the history years failed', error);
    rethrow;
  }
}, retry: _noRetry);

/// Plays per local day of a year, for the days that have any, newest first.
final historyDayCountsProvider = FutureProvider.autoDispose
    .family<List<HistoryDayCount>, int>((ref, year) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(historyPlaysVersionProvider);
      if (db == null) return const [];
      try {
        return await db.historyDayCounts(dayBoundsOfYear(year));
      } on Object catch (error) {
        logHistoryError('Reading the history days failed', error);
        rethrow;
      }
    }, retry: _noRetry);

/// Plays and distinct songs in `[start, end)` (a year of the History toolbar,
/// the window of Most played).
final historyRangeSummaryProvider = FutureProvider.autoDispose
    .family<HistoryRangeSummary, ({int start, int end})>((ref, range) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(historyPlaysVersionProvider);
      if (db == null) return (plays: 0, tracks: 0);
      try {
        return await db.historyRangeSummary(range.start, range.end);
      } on Object catch (error) {
        logHistoryError('Reading the history range totals failed', error);
        rethrow;
      }
    }, retry: _noRetry);

/// Totals, first play and collage covers of the whole history. Cover keys come
/// from `tracks`, so a scan reads it again too.
final historyOverviewProvider = FutureProvider.autoDispose<HistoryOverview>((
  ref,
) async {
  final db = ref.watch(libraryDatabaseProvider);
  ref.watch(historyPlaysVersionProvider);
  ref.watch(historyTracksVersionProvider);
  if (db == null) {
    return const HistoryOverview(
      plays: 0,
      tracks: 0,
      firstPlayedAt: null,
      coverKeys: [],
    );
  }
  try {
    return await db.historyOverview();
  } on Object catch (error) {
    logHistoryError('Reading the history overview failed', error);
    rethrow;
  }
}, retry: _noRetry);

/// First and last play, or null when there are none: the bounds of the range
/// picker, and what tells a range that takes in every play.
final historyPlayedRangeProvider =
    FutureProvider.autoDispose<({int first, int last})?>((ref) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(historyPlaysVersionProvider);
      if (db == null) return null;
      try {
        return await db.historyPlayedRange();
      } on Object catch (error) {
        logHistoryError('Reading the played range failed', error);
        rethrow;
      }
    }, retry: _noRetry);

/// The most played songs in `[start, end)` (all time when both are null),
/// at most `historyTopLimit + 1` (the extra row tells the page the list was
/// cut). It reads again after a change to the plays and,
/// at most once per browse interval, after a scan.
final historyTopProvider = StreamProvider.autoDispose
    .family<List<HistoryTopRow>, ({int? start, int? end})>((ref, window) {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(historyPlaysVersionProvider);
      if (db == null) return Stream.value(const <HistoryTopRow>[]);
      return throttledTracksQuery(db, () async {
        try {
          return await db.historyTopPlays(
            start: window.start,
            end: window.end,
            limit: historyTopLimit + 1,
          );
        } on Object catch (error) {
          logHistoryError('Reading the most played failed', error);
          rethrow;
        }
      }, interval: ref.watch(libraryBrowseRefreshIntervalProvider));
    }, retry: _noRetry);

/// What the page of one song shows: its totals and every play, newest first.
typedef HistoryTrackPage = ({
  HistoryTrackSummary summary,
  List<HistoryPlayRow> plays,
});

/// The page of the song at [path]. The totals and the plays are read in one
/// transaction, so the count in the header and the list always agree. It
/// reads again after a new or removed play (not after a checkpoint of the
/// time listened) and, at most once per browse interval, after a scan.
final historyTrackProvider = StreamProvider.autoDispose
    .family<HistoryTrackPage, String>((ref, path) {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(historyPlaysVersionProvider);
      if (db == null) {
        return Stream.value((
          summary: HistoryTrackSummary(path: path, count: 0),
          plays: const <HistoryPlayRow>[],
        ));
      }
      return throttledTracksQuery(db, () async {
        try {
          return await db.transaction(
            () async => (
              summary: await db.historyTrackSummary(path),
              plays: await db.historyTrackPlays(path),
            ),
          );
        } on Object catch (error) {
          logHistoryError('Reading the song history failed', error);
          rethrow;
        }
      }, interval: ref.watch(libraryBrowseRefreshIntervalProvider));
    }, retry: _noRetry);
