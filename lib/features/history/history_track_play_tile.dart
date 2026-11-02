import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/format_duration.dart';
import '../../shared/widgets/context_menu_more_button.dart';
import '../../shared/widgets/context_menu_region.dart';

/// Fixed height of a line of the song history list.
const historyTrackRowExtent = 56.0;

/// One play on the page of a song: the day and time it started, how long it
/// was listened to (left out when unknown), the "Nth listen" badge and a more
/// button.
///
/// The menu opens on a right click, a long press, the Menu key, Shift+F10 and
/// the more button, always through [onMenu] with the pointer position (a
/// point near the row start for a key). The keys work while focus is in the
/// row, which today is its more button. Removing a play is only in that menu,
/// never one tap on the row: a play of the song now playing is added at the
/// top and would move the rows under the pointer.
class HistoryTrackPlayTile extends StatelessWidget {
  const HistoryTrackPlayTile({
    super.key,
    required this.row,
    required this.onMenu,
  });

  final HistoryPlayRow row;

  /// Opens the menu at the given global point.
  final ContextMenuOpen onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dates = MaterialLocalizations.of(context);
    final at = DateTime.fromMillisecondsSinceEpoch(row.playedAt);
    final when =
        '${dates.formatMediumDate(at)} · '
        '${dates.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final listened = row.listenedMs;
    final nth = row.nth;

    final content = Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (listened != null)
                Text(
                  l10n.historyListened(
                    formatDuration(Duration(milliseconds: listened)),
                  ),
                  style: small,
                ),
            ],
          ),
        ),
        if (nth != null)
          Tooltip(
            message: l10n.historyNthPlayLabel(nth),
            child: Semantics(
              label: l10n.historyNthPlayLabel(nth),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l10n.historyNthPlay(nth), style: small),
              ),
            ),
          ),
        ContextMenuMoreButton(onOpen: onMenu),
      ],
    );

    return SizedBox(
      height: historyTrackRowExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: ContextMenuRegion(
          onOpen: onMenu,
          child: Material(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            child: content,
          ),
        ),
      ),
    );
  }
}
