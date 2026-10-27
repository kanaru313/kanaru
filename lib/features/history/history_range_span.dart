import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'history_days.dart';
import 'history_range.dart';

/// The days from [first] to [last] (inclusive, local midnights) as dates in
/// [locale]: one date for a single day, "Sep 27 – Oct 26, 2026" inside one
/// year and "Dec 30, 2025 – Jan 5, 2026" across two. The year is written once
/// when both ends share it, in the order the locale uses.
String historySpanText(String locale, DateTime first, DateTime last) {
  final full = DateFormat.yMMMd(locale);
  if (!last.isAfter(first)) return full.format(first);
  final start = first.year == last.year ? DateFormat.MMMd(locale) : full;
  return '${start.format(first)} – ${full.format(last)}';
}

/// [historySpanText] for a range of whole days (the end is the day after the
/// last one, as `HistoryRangeState.days` returns it), in the app's locale.
String historyRangeSpan(
  BuildContext context,
  ({DateTime start, DateTime end}) days,
) => historySpanText(
  Localizations.localeOf(context).toString(),
  days.start,
  addDays(days.end, -1),
);

/// The range of the Most played pane in words: preset, a dot, then the span
/// ("30 days · Sep 27 – Oct 26, 2026"), or just
/// "All time" when the range has no end.
String mostPlayedRangeLine(
  BuildContext context,
  HistoryRangeState state,
  DateTime now,
) {
  final l10n = context.l10n;
  final days = state.days(now);
  if (days == null) return l10n.historyRangeAll;
  final label = switch (state.preset) {
    HistoryRangePreset.today => l10n.historyRangeToday,
    HistoryRangePreset.days7 => l10n.historyRange7Days,
    HistoryRangePreset.days30 => l10n.historyRange30Days,
    HistoryRangePreset.months6 => l10n.historyRange6Months,
    HistoryRangePreset.year => l10n.historyRangeYear,
    HistoryRangePreset.all => l10n.historyRangeAll,
    HistoryRangePreset.custom => l10n.historyRangeCustom,
  };
  return '$label · ${historyRangeSpan(context, days)}';
}
