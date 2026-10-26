import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'history_days.dart';
import 'history_range.dart';

/// What the range is called: "Today" for the current day, "All time", else
/// the first and last day in the medium date format. Also names the playlist
/// made from the list.
String historyRangeText(
  BuildContext context,
  HistoryRangeState state,
  DateTime now,
) {
  final l10n = context.l10n;
  final days = state.days(now);
  if (days == null) return l10n.historyRangeAll;
  if (state.preset == HistoryRangePreset.today && state.back == 0) {
    return l10n.historyRangeToday;
  }
  final dates = MaterialLocalizations.of(context);
  return l10n.historyRangeLabel(
    dates.formatMediumDate(days.start),
    dates.formatMediumDate(addDays(days.end, -1)),
  );
}

/// The range controls of the Most played page: a chip per preset and one for a
/// custom range, then (except for all time) buttons that step to the period
/// before or after with the range between them.
class HistoryRangeBar extends StatelessWidget {
  const HistoryRangeBar({
    super.key,
    required this.state,
    required this.now,
    required this.canPickCustom,
    required this.onPreset,
    required this.onCustom,
    required this.onShift,
  });

  final HistoryRangeState state;
  final DateTime now;

  /// False while there is no play to pick a day among.
  final bool canPickCustom;
  final ValueChanged<HistoryRangePreset> onPreset;
  final VoidCallback onCustom;

  /// Called with -1 for the previous period and 1 for the next.
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      HistoryRangePreset.today: l10n.historyRangeToday,
      HistoryRangePreset.days7: l10n.historyRange7Days,
      HistoryRangePreset.days30: l10n.historyRange30Days,
      HistoryRangePreset.months6: l10n.historyRange6Months,
      HistoryRangePreset.year: l10n.historyRangeYear,
      HistoryRangePreset.all: l10n.historyRangeAll,
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
          child: Row(
            children: [
              for (final e in labels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: state.preset == e.key,
                    onSelected: (_) => onPreset(e.key),
                  ),
                ),
              ChoiceChip(
                label: Text(l10n.historyRangeCustom),
                selected: state.preset == HistoryRangePreset.custom,
                onSelected: canPickCustom ? (_) => onCustom() : null,
              ),
            ],
          ),
        ),
        if (state.preset != HistoryRangePreset.all)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(AppIcons.chevronLeft),
                tooltip: l10n.historyRangePrevious,
                onPressed: () => onShift(-1),
              ),
              Flexible(
                child: Text(
                  historyRangeText(context, state, now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.chevronRight),
                tooltip: l10n.historyRangeNext,
                onPressed: state.canGoNext(now) ? () => onShift(1) : null,
              ),
            ],
          ),
      ],
    );
  }
}
