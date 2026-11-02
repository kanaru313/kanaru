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

/// One play of the timeline: the library song row with "date - time" as its
/// third line and the "#N" listen badge above the duration. A play whose file
/// is not in the library shows its file name, is dimmed and does not play.
/// Only the newest play of the playing track gets the playing fill.
///
/// A row in the library opens the song modal (right click, long press, Menu
/// key, Shift+F10 or the ⋮ button) with [modalExtras]. A missing file has no
/// song modal: its small menu opens through [onMenu] with the pointer position
/// (the row's start for the key). Removing a play is only in those menus,
/// never one tap on the row: the list moves under the pointer when plays come
/// and go.
class HistoryPlayRowTile extends ConsumerWidget {
  const HistoryPlayRowTile({
    super.key,
    required this.row,
    required this.onTap,
    required this.onMenu,
    required this.onQueueAction,
    required this.modalExtras,
  });

  final HistoryPlayRow row;

  /// Plays from this row; ignored on a play that cannot play.
  final VoidCallback onTap;

  /// Opens the menu of a missing file at the given global point.
  final ContextMenuOpen onMenu;

  /// Queue action picked in the song modal of a row in the library.
  final ValueChanged<QueueAction> onQueueAction;

  /// Song history and Remove from history, built when the modal opens.
  final SongModalExtrasBuilder modalExtras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final played = DateTime.fromMillisecondsSinceEpoch(row.playedAt);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(played),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final playedAt = l10n.historyPlayedAt(played, time);
    final nth = row.nth;
    final track = row.track;
    // Only the newest play of the playing track is marked, not every listen
    // of it in the journal. SongTile takes this value, so the fill and the
    // badge colour (readable on the primaryContainer card) always agree.
    final playing =
        track != null &&
        row.latest &&
        ref.watch(playingTrackPathProvider.select((p) => p == track.path));

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
              color: playing
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (track != null) {
      return SongTile(
        song: track,
        onTap: onTap,
        detail: playedAt,
        badge: badge,
        playing: playing,
        onQueueAction: onQueueAction,
        modalExtras: modalExtras,
      );
    }
    return MissingSongRow(
      path: row.path,
      detail: playedAt,
      badge: badge,
      onMenu: onMenu,
    );
  }
}
