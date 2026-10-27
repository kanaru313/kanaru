import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_queries.dart';
import '../../core/database/library_startup.dart';
import 'history_days.dart';
import 'history_error_log.dart';
import 'history_range_calendar.dart';
import 'history_range_dialog_header.dart';

typedef HistoryDayRange = ({DateTime start, DateTime end});

/// Asks for a range of days in a centred dialog with one month at a time.
/// Only days in [bounds] can be picked; [initial] (inside the bounds) is
/// selected at first and [today] is outlined. Returns the first and last day
/// (local midnights), or null when the dialog was dismissed.
Future<HistoryDayRange?> showHistoryRangeDialog(
  BuildContext context, {
  required ({DateTime first, DateTime last}) bounds,
  required DateTime today,
  HistoryDayRange? initial,
}) => showDialog<HistoryDayRange>(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: HistoryRangePicker(
        bounds: bounds,
        today: localDay(today),
        initial: initial,
      ),
    ),
  ),
);

/// The selection after a tap on [day]: with no start, or a complete range, the
/// day starts a new one; a day on or after the start ends it (the same day is
/// a one-day range); an earlier day becomes the new start.
({DateTime? start, DateTime? end}) applyRangeTap(
  DateTime? start,
  DateTime? end,
  DateTime day,
) {
  if (start == null || end != null) return (start: day, end: null);
  return day.isBefore(start)
      ? (start: day, end: null)
      : (start: start, end: day);
}

/// The dialog's content: title, month bar, calendar, hint and buttons. The
/// selection lives here, so it stays while the calendar pages.
class HistoryRangePicker extends ConsumerStatefulWidget {
  const HistoryRangePicker({
    super.key,
    required this.bounds,
    required this.today,
    this.initial,
  });

  final ({DateTime first, DateTime last}) bounds;
  final DateTime today;
  final HistoryDayRange? initial;

  @override
  ConsumerState<HistoryRangePicker> createState() => _HistoryRangePickerState();
}

class _HistoryRangePickerState extends ConsumerState<HistoryRangePicker> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _focused;

  /// Start (epoch ms) of every local day known to have plays.
  final _playDays = <int>{};

  /// Months whose days were asked for, keyed by month and first weekday: a
  /// locale with another week start shows other days around the month.
  final _loaded = <int>{};

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end = widget.initial?.end;
    _focused = _clamp(widget.initial?.end ?? widget.today);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The page change callback does not fire for the first page.
    _loadMonth(_focused);
  }

  DateTime _clamp(DateTime day) {
    final d = localDay(day);
    if (d.isBefore(widget.bounds.first)) return widget.bounds.first;
    if (d.isAfter(widget.bounds.last)) return widget.bounds.last;
    return d;
  }

  /// Reads which days of the 6-week grid of [month] have plays.
  Future<void> _loadMonth(DateTime month) async {
    final weekStart = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final key = (month.year * 12 + month.month) * 7 + weekStart;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || !_loaded.add(key)) return;
    final first = DateTime(month.year, month.month);
    final lead = (first.weekday % 7 - weekStart + 7) % 7;
    final gridStart = addDays(first, -lead);
    try {
      final days = await db.historyPlayDayStarts(
        dayBoundsBetween(gridStart, addDays(gridStart, 42)),
      );
      if (mounted) setState(() => _playDays.addAll(days));
    } on Object catch (error) {
      _loaded.remove(key);
      logHistoryError('Reading the days with plays failed', error);
    }
  }

  void _focus(DateTime day) {
    // The package hands out UTC dates; the app works in local days.
    final local = _clamp(localDay(day));
    setState(() => _focused = local);
    _loadMonth(local);
  }

  void _step(int months) =>
      _focus(DateTime(_focused.year, _focused.month + months));

  void _tap(DateTime day) {
    final local = localDay(day);
    final next = applyRangeTap(_start, _end, local);
    setState(() {
      _start = next.start;
      _end = next.end;
    });
    _focus(local);
  }

  void _save() {
    final start = _start;
    final end = _end;
    if (start != null && end != null) {
      Navigator.of(context).pop((start: start, end: end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = widget.bounds;
    final month = DateTime(_focused.year, _focused.month);
    final canGoBack = month.isAfter(
      DateTime(bounds.first.year, bounds.first.month),
    );
    final canGoOn = month.isBefore(
      DateTime(bounds.last.year, bounds.last.month),
    );
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => saveOnEnter(context, event, _save),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HistoryRangeDialogHeader(start: _start, end: _end),
            const SizedBox(height: 8),
            HistoryMonthBar(
              month: month,
              onPrevious: canGoBack ? () => _step(-1) : null,
              onNext: canGoOn ? () => _step(1) : null,
            ),
            HistoryRangeCalendar(
              bounds: bounds,
              today: widget.today,
              focused: _focused,
              start: _start,
              end: _end,
              playDays: _playDays,
              onDayTap: _tap,
              onPageChanged: _focus,
            ),
            const SizedBox(height: 8),
            HistoryRangeFooter(
              hint: historyRangeHint(context, _start, _end),
              onSave: _start != null && _end != null ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
