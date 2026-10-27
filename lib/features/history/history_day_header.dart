import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'history_days.dart';

/// The line that starts a day: "Today", "Yesterday" or the full date, and
/// how many plays the day has. Opaque, so it can sit over the rows scrolling
/// under it as the sticky header.
class HistoryDayHeader extends StatelessWidget {
  const HistoryDayHeader({
    super.key,
    required this.day,
    required this.count,
    required this.now,
  });

  final DateTime day;
  final int count;

  /// The current time, which tells today from yesterday.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = localDay(now);
    final label = isSameDay(day, today)
        ? l10n.historyToday
        : isSameDay(day, addDays(today, -1))
        ? l10n.historyYesterday
        : MaterialLocalizations.of(context).formatFullDate(day);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.historyListenCount(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
