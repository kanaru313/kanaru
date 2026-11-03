import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/player/playing_track_path.dart';
import '../../l10n/l10n.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/context_menu_region.dart';
import '../../shared/widgets/missing_song_row.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart';

/// One entry of the Most played list: the library song row, numbered by its
/// rank (the first three in the accent colour) with the number of listens
/// above the duration. A song no longer in the library shows its file name,
/// is dimmed and does not play.
///
/// A row in the library opens the song modal (right click, long press, Menu
/// key, Shift+F10 or the ⋮ button) with [modalExtras]. A missing file opens its
/// Missing-play modal through [onMenu].
class MostPlayedRowTile extends ConsumerWidget {
  const MostPlayedRowTile({
    super.key,
    required this.rank,
    required this.row,
    required this.onTap,
    required this.onMenu,
    required this.onQueueAction,
    required this.modalExtras,
  });

  /// Place in the ranking, from 1; kept while a filter hides other rows.
  final int rank;
  final HistoryTopRow row;

  /// Plays from this row; ignored on a song that cannot play.
  final VoidCallback onTap;

  /// Opens the modal of a missing file.
  final ContextMenuOpen onMenu;

  /// Queue action picked in the song modal of a row in the library.
  final ValueChanged<QueueAction> onQueueAction;

  /// Song history and the rank chip, built when the modal opens.
  final SongModalExtrasBuilder modalExtras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = row.track;
    // SongTile takes this value, so the fill and the rank and badge colours
    // always agree.
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

    if (track != null) {
      return SongTile(
        song: track,
        onTap: onTap,
        leadingAccessory: number,
        badge: badge,
        playing: playing,
        onQueueAction: onQueueAction,
        modalExtras: modalExtras,
      );
    }
    return MissingSongRow(
      path: row.path,
      leading: number,
      badge: badge,
      onMenu: onMenu,
    );
  }
}
