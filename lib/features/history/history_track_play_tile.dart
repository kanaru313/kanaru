import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/format_duration.dart';
import '../../shared/icons/app_icons.dart';

/// Fixed height of a line of the song history list.
const historyTrackRowExtent = 56.0;

/// One play on the page of a song: the day and time it started, how long it
/// was listened to (left out when unknown), the "Nth listen" badge and a more
/// button.
///
/// The menu opens on a right click, a long press and the more button, always
/// through [onMenu] with the pointer position. Removing a play is only in
/// that menu, never one tap on the row: a play of the song now playing is
/// added at the top and would move the rows under the pointer.
class HistoryTrackPlayTile extends StatelessWidget {
  const HistoryTrackPlayTile({
    super.key,
    required this.row,
    required this.onMenu,
  });

  final HistoryPlayRow row;

  /// Opens the menu with its corner at the given global position.
  final ValueChanged<Offset> onMenu;

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
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(AppIcons.more),
            iconSize: 20,
            tooltip: l10n.historyMore,
            onPressed: () {
              final box = context.findRenderObject()! as RenderBox;
              onMenu(box.localToGlobal(Offset(0, box.size.height)));
            },
          ),
        ),
      ],
    );

    return SizedBox(
      height: historyTrackRowExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (d) => onMenu(d.globalPosition),
          onLongPressStart: (d) => onMenu(d.globalPosition),
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
