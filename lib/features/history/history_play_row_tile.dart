import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/menu_keyboard_region.dart';
import '../../shared/widgets/song_row_view.dart';
import '../../shared/widgets/song_tile.dart';

/// One play of the timeline: the library song row with "date - time" as its
/// third line and the "#N" listen badge above the duration. A play whose file
/// is not in the library shows its file name, is dimmed and does not play.
///
/// The menu opens on a right click, a long press and the Menu key, through
/// [onMenu] with the pointer position (the row's start for the key). Removing
/// a play is only in that menu, never one tap on the row: the list moves
/// under the pointer when plays come and go.
class HistoryPlayRowTile extends StatelessWidget {
  const HistoryPlayRowTile({
    super.key,
    required this.row,
    required this.onTap,
    required this.onMenu,
  });

  final HistoryPlayRow row;

  /// Plays from this row; ignored on a play that cannot play.
  final VoidCallback onTap;

  /// Opens the menu with its corner at the given global position.
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final played = DateTime.fromMillisecondsSinceEpoch(row.playedAt);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(played),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final playedAt = l10n.historyPlayedAt(played, time);
    final nth = row.nth;
    final track = row.track;

    Widget? badge;
    if (nth != null) {
      final theme = Theme.of(context);
      badge = Tooltip(
        message: l10n.historyNthPlayLabel(nth),
        child: Semantics(
          label: l10n.historyNthPlayLabel(nth),
          excludeSemantics: true,
          child: Text(
            l10n.historyNthPlay(nth),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // A missing play has no ink well to take focus, so it is a focus stop of
    // its own: the Menu key needs focus inside the region.
    final Widget content = track == null
        ? Focus(
            child: Opacity(
              opacity: 0.6,
              child: SongRowView(
                title: row.path.split('/').last,
                artist: l10n.historyTrackMissing,
                detail: playedAt,
                badge: badge,
              ),
            ),
          )
        : SongTile(song: track, onTap: onTap, detail: playedAt, badge: badge);
    return MenuKeyboardRegion(
      onOpen: onMenu,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) => onMenu(d.globalPosition),
        onLongPressStart: (d) => onMenu(d.globalPosition),
        child: content,
      ),
    );
  }
}
