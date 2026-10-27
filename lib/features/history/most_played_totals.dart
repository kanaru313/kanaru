import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/history_rows.dart';
import 'history_providers.dart';
import 'history_range.dart';

/// The totals of the window the Most played pane describes, or null while
/// that window's totals are being read: a window's totals are never shown for
/// another window, so the pane's range line and its counts always agree.
///
/// A null [window] is all time (or a window that takes in every play); that
/// comes from the overview, which is cheaper. [playedKnown] is false while the
/// span of days with plays is being read, when nothing is read; [anyPlayed] is
/// false for a library with no plays, whose totals are zero without a read.
HistoryRangeSummary? watchMostPlayedTotals(
  WidgetRef ref,
  ({int start, int end})? window, {
  required bool playedKnown,
  required bool anyPlayed,
}) {
  if (!playedKnown) return null;
  if (!anyPlayed) return (plays: 0, tracks: 0);
  if (window != null) {
    return ref.watch(historyRangeSummaryProvider(window)).value;
  }
  final overview = ref.watch(historyOverviewProvider).value;
  return overview == null
      ? null
      : (plays: overview.plays, tracks: overview.tracks);
}

/// The ranking on show: the last list read, cut at [historyTopLimit]. It is
/// kept while the next list is read, so the page never flashes empty, and it
/// is the same list object until the next read, so the filter index is built
/// once per read.
class MostPlayedRows {
  List<HistoryTopRow>? _read;
  List<HistoryTopRow>? _rows;
  var _capped = false;

  /// The rows to show; null before the first read.
  List<HistoryTopRow>? get rows => _rows;

  /// Whether the read had more rows than are shown.
  bool get capped => _capped;

  /// Takes [read] as the list on show; a no-op for the list already taken.
  void keep(List<HistoryTopRow> read) {
    if (identical(read, _read)) return;
    _read = read;
    // One row past the limit was read only to know the list was cut.
    _capped = read.length > historyTopLimit;
    _rows = _capped ? read.sublist(0, historyTopLimit) : read;
  }
}
