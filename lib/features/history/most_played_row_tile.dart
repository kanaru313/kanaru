import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/player/playing_track_path.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/menu_keyboard_region.dart';
import '../../shared/widgets/song_row_view.dart';
import '../../shared/widgets/song_tile.dart';

/// One entry of the Most played list: the library song row, numbered by its
/// rank (the first three in the accent colour) with the number of listens
/// above the duration. A song no longer in the library shows its file name,
/// is dimmed and does not play.
///
/// The menu opens on a right click, a long press and the Menu key, through
/// [onMenu] with the pointer position (the row's start for the key).
class MostPlayedRowTile extends ConsumerWidget {
  const MostPlayedRowTile({
    super.key,
    required this.rank,
    required this.row,
    required this.onTap,
    required this.onMenu,
  });

  /// Place in the ranking, from 1; kept while a filter hides other rows.
  final int rank;
  final HistoryTopRow row;

  /// Plays from this row; ignored on a song that cannot play.
  final VoidCallback onTap;

  /// Opens the menu with its corner at the given global position.
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = row.track;
    final playing =
        track != null &&
        ref.watch(playingTrackPathProvider.select((p) => p == track.path));
    final onFill = playing ? colors.onPrimaryContainer : null;

    final top = rank <= 3;
    final number = SizedBox(
      width: 32,
      child: Text(
        '$rank',
        textAlign: TextAlign.end,
        style: theme.textTheme.bodySmall?.copyWith(
          color: onFill ?? (top ? colors.primary : colors.onSurfaceVariant),
          fontWeight: top ? FontWeight.w700 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    // Plain text, no chip padding: the trailing column has no height to spare.
    final badge = Text(
      l10n.historyTopPlayCount(row.count),
      style: theme.textTheme.labelSmall?.copyWith(
        color: onFill ?? colors.onSurfaceVariant,
      ),
    );

    // A missing song has no ink well to take focus, so it is a focus stop of
    // its own: the Menu key needs focus inside the region.
    final Widget content = track == null
        ? Focus(
            child: Opacity(
              opacity: 0.6,
              child: SongRowView(
                leading: number,
                title: row.path.split('/').last,
                artist: l10n.historyTrackMissing,
                badge: badge,
              ),
            ),
          )
        : SongTile(
            song: track,
            onTap: onTap,
            leadingAccessory: number,
            badge: badge,
          );
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
