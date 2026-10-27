import 'package:material_ui/material_ui.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../l10n/l10n.dart';
import 'history_calendar_style.dart';
import 'history_days.dart';

/// The month grid of the range dialog: [start] to [end] highlighted, a dot on
/// the days in [playDays], days outside [bounds] off. Dates the package hands
/// out are UTC midnights; everything that leaves this widget is a local day.
class HistoryRangeCalendar extends StatelessWidget {
  const HistoryRangeCalendar({
    super.key,
    required this.bounds,
    required this.today,
    required this.focused,
    required this.start,
    required this.end,
    required this.playDays,
    required this.onDayTap,
    required this.onPageChanged,
  });

  final ({DateTime first, DateTime last}) bounds;
  final DateTime today;

  /// A local day of the month in view.
  final DateTime focused;
  final DateTime? start;
  final DateTime? end;

  /// Start (epoch ms) of each local day with plays.
  final Set<int> playDays;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onPageChanged;

  bool _isEdge(DateTime day) =>
      start != null && isSameDay(day, start!) ||
      end != null && isSameDay(day, end!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    return TableCalendar<void>(
      locale: Localizations.localeOf(context).toString(),
      firstDay: bounds.first,
      lastDay: bounds.last,
      focusedDay: focused,
      currentDay: today,
      rangeStartDay: start,
      rangeEndDay: end,
      // The package's range mode swaps an earlier second tap and ignores a
      // repeated one; the dialog applies its own rule in `onDayTap`.
      rangeSelectionMode: RangeSelectionMode.disabled,
      // The package's header is built from `package:flutter/material.dart`
      // widgets, which do not find the app's Material.
      headerVisible: false,
      sixWeekMonthsEnforced: true,
      pageJumpingEnabled: true,
      rowHeight: historyCalendarRowHeight,
      startingDayOfWeek: historyStartingDay(loc),
      availableGestures: AvailableGestures.horizontalSwipe,
      calendarStyle: historyCalendarStyle(theme),
      daysOfWeekStyle: historyDaysOfWeekStyle(theme, loc),
      // The package's cell node keeps only the date label and drops what is
      // inside the cell; the marker is a sibling, so its node merges in.
      loadEventsForDisabledDays: true,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, _) {
          final local = localDay(day);
          final disabled =
              local.isBefore(bounds.first) || local.isAfter(bounds.last);
          final hasPlays =
              !disabled && playDays.contains(local.millisecondsSinceEpoch);
          return Semantics(
            button: true,
            enabled: !disabled,
            selected: _isEdge(local),
            label: hasPlays ? context.l10n.historyRangeDayHasListens : null,
            child: const SizedBox.shrink(),
          );
        },
        prioritizedBuilder: (context, day, focusedMonth) {
          final local = localDay(day);
          return HistoryDayCell(
            day: local,
            isOutside: day.month != focusedMonth.month,
            isDisabled:
                local.isBefore(bounds.first) || local.isAfter(bounds.last),
            isToday: isSameDay(local, today),
            isEdge: _isEdge(local),
            hasPlays: playDays.contains(local.millisecondsSinceEpoch),
          );
        },
      ),
      onDaySelected: (day, _) => onDayTap(localDay(day)),
      onPageChanged: (day) => onPageChanged(localDay(day)),
    );
  }
}
