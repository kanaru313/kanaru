import 'dart:math' as math;

import '../../core/database/history_rows.dart';
import 'history_line_metrics.dart';

/// Position of every line of the timeline, from the plays per day alone.
///
/// Each day is one header line followed by one line per play; when an older
/// year exists a last line offers it. The list is flat so one extent-builder
/// list can draw it: finding the day of a line is a binary search, and no
/// row data is needed to lay the list out.
class HistoryTimelineIndex {
  /// [days] are the days with plays, newest first.
  HistoryTimelineIndex(this.days, {this.hasOlderYear = false}) {
    var total = 0;
    _starts = [0];
    for (final d in days) {
      total += 1 + d.count;
      _starts.add(total);
    }
    itemCount = total + (hasOlderYear ? 1 : 0);
  }

  final List<HistoryDayCount> days;

  /// A line after the last day leads to an older year.
  final bool hasOlderYear;

  /// Lines in the list.
  late final int itemCount;

  /// First line of day `i`; the last entry is the end of the last day.
  late final List<int> _starts;

  /// Whether line [i] is the older-year line.
  bool isFooter(int i) => hasOlderYear && i == _starts.last;

  /// Index into [days] of the day line [i] belongs to; [days] `.length` for
  /// the older-year line.
  int dayIndexAtItem(int i) {
    assert(i >= 0 && i < itemCount, 'line $i is outside the list');
    var lo = 0;
    var hi = days.length;
    // Largest day whose first line is at or before i.
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_starts[mid] <= i) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The day and the row inside it of line [i]; the row is -1 on the header.
  ({int day, int row}) itemAt(int i) {
    final day = dayIndexAtItem(i);
    return (day: day, row: day == days.length ? -1 : i - _starts[day] - 1);
  }

  /// Whether line [i] is the header line of a day.
  bool isHeader(int i) {
    final day = dayIndexAtItem(i);
    return day < days.length && _starts[day] == i;
  }

  /// Scroll offset of the top of the header line of day [day] (index into
  /// [days]). Header lines are `m.header` tall, every other line `m.line`;
  /// one header comes with each earlier day.
  double headerOffsetOfDay(int day, HistoryLineMetrics m) =>
      (_starts[day] - day) * m.line + day * m.header;

  /// Scroll offset at which the date bar of day [day] (index into [days]) is
  /// at the top of the list: [HistoryLineMetrics.topGap] below its header
  /// line's top.
  double barOffsetOfDay(int day, HistoryLineMetrics m) =>
      headerOffsetOfDay(day, m) + m.topGap;

  /// Index into [days] of the day starting at [dayStart] (epoch ms), or -1.
  int dayIndexOfStart(int dayStart) => _dayIndexOfStart(dayStart);

  /// The day whose bar the sticky bar shows at scroll [offset], and how far
  /// that bar is pushed up by the next day's bar (`dy` in `(-bar, 0]`). Null
  /// while the first bar is still in place in the list.
  ({int day, double dy})? stickyAt(double offset, HistoryLineMetrics m) {
    if (days.isEmpty || offset < barOffsetOfDay(0, m)) return null;
    // Last day whose bar is at or above the top (offsets grow with the day).
    var lo = 0;
    var hi = days.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (barOffsetOfDay(mid, m) <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final next = lo + 1 < days.length
        ? barOffsetOfDay(lo + 1, m)
        : double.infinity;
    return (day: lo, dy: math.min(0.0, next - offset - m.bar));
  }

  /// The line of the header of the day starting at [dayStart] (epoch ms), or
  /// -1 when that day has no plays.
  int firstIndexOfDay(int dayStart) {
    final day = _dayIndexOfStart(dayStart);
    return day < 0 ? -1 : _starts[day];
  }

  /// Plays the list shows for the day starting at [dayStart] (epoch ms), or
  /// -1 when that day has no plays.
  int countOfDay(int dayStart) {
    final day = _dayIndexOfStart(dayStart);
    return day < 0 ? -1 : days[day].count;
  }

  int _dayIndexOfStart(int dayStart) {
    var lo = 0;
    var hi = days.length - 1;
    // Days run newest first, so their starts decrease.
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final start = days[mid].dayStart;
      if (start == dayStart) return mid;
      if (start > dayStart) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }
}
