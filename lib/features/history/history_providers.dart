import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import 'history_days.dart';
import 'history_error_log.dart';
import 'history_plays_version.dart';

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
