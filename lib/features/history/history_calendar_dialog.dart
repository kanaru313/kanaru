import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Opens a month grid of [year] with a dot under each day that has plays in
/// [counts]; days without plays are disabled. Returns the day picked, or null
/// when the dialog was dismissed.
Future<DateTime?> showHistoryCalendar(
  BuildContext context, {
  required int year,
  required List<HistoryDayCount> counts,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: HistoryCalendar(year: year, counts: counts),
    ),
  ),
);

int _dayKey(int year, int month, int day) => year * 10000 + month * 100 + day;

/// The month grid inside the dialog: one month at a time, within [year].
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({super.key, required this.year, required this.counts});

  final int year;

  /// Days with plays, newest first.
  final List<HistoryDayCount> counts;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  late final Map<int, int> _plays;
  late int _month;

  @override
  void initState() {
    super.initState();
    _plays = {
      for (final c in widget.counts)
        _dayKey(
          widget.year,
          DateTime.fromMillisecondsSinceEpoch(c.dayStart).month,
          DateTime.fromMillisecondsSinceEpoch(c.dayStart).day,
        ): c.count,
    };
    // Opens on the month of the latest play.
    _month = widget.counts.isEmpty
        ? 1
        : DateTime.fromMillisecondsSinceEpoch(widget.counts.first.dayStart)
              .month;
  }

  void _step(int by) => setState(() => _month += by);

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = DateTime(widget.year, _month);
    final days = DateTime(widget.year, _month + 1, 0).day;
    // Sunday is 0 in the localizations' weekday lists; DateTime's is 7.
    final lead = (first.weekday % 7 - loc.firstDayOfWeekIndex + 7) % 7;
    final weeks = (lead + days + 6) ~/ 7;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(AppIcons.chevronLeft),
                tooltip: loc.previousMonthTooltip,
                onPressed: _month > 1 ? () => _step(-1) : null,
              ),
              Expanded(
                child: Text(
                  loc.formatMonthYear(first),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.chevronRight),
                tooltip: loc.nextMonthTooltip,
                onPressed: _month < 12 ? () => _step(1) : null,
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      loc.narrowWeekdays[(loc.firstDayOfWeekIndex + i) % 7],
                    ),
                  ),
                ),
            ],
          ),
          for (var w = 0; w < weeks; w++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(child: _cell(context, w * 7 + i - lead + 1, days)),
              ],
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.closeButtonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 44);
    final theme = Theme.of(context);
    final plays = _plays[_dayKey(widget.year, _month, day)];
    final date = DateTime(widget.year, _month, day);
    final enabled = plays != null;
    final color = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      excludeSemantics: true,
      button: enabled,
      enabled: enabled,
      label: enabled
          ? '${MaterialLocalizations.of(context).formatFullDate(date)}, '
                '${context.l10n.historyListenCount(plays)}'
          : MaterialLocalizations.of(context).formatFullDate(date),
      child: InkResponse(
        key: ValueKey('history-calendar-day-$day'),
        onTap: enabled ? () => Navigator.of(context).pop(date) : null,
        radius: 22,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: TextStyle(color: color)),
              const SizedBox(height: 2),
              SizedBox.square(
                dimension: 5,
                child: enabled
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
