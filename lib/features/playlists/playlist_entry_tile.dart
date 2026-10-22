import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/format_duration.dart';
import '../../shared/widgets/cover_art.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart' show songCoverSize;

/// Fixed row height, which lets the list place rows without measuring them.
const playlistEntryExtent = 64.0;

/// One playlist entry: drag handle, cover, title with "artist · album",
/// length and a remove button. An entry whose file is not in the library
/// shows its file name, is dimmed and does not play.
class PlaylistEntryTile extends ConsumerWidget {
  const PlaylistEntryTile({
    super.key,
    required this.entry,
    required this.index,
    this.onTap,
    required this.onRemove,
    this.onQueueAction,
  });

  final PlaylistEntryRow entry;

  /// Position in the list as shown, for the drag handle.
  final int index;

  /// Plays from this row; null on an entry that cannot play.
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = entry.track;
    final durationMs = track?.durationMs;
    final details = [
      track?.artist,
      track?.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    final row = Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Tooltip(
              message: l10n.playlistReorder,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle_rounded, size: 20),
              ),
            ),
          ),
        ),
        CoverArt(
          path: coverPath(
            ref.watch(coverCacheDirectoryProvider),
            track?.coverKey,
          ),
          size: songCoverSize,
          placeholder: Center(
            child: Icon(
              track == null
                  ? Icons.music_off_outlined
                  : Icons.music_note_outlined,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? entry.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (track == null || details.isNotEmpty)
                Text(
                  track == null ? l10n.playlistNotInLibrary : details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (durationMs != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              formatDuration(Duration(milliseconds: durationMs)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          iconSize: 20,
          tooltip: l10n.playlistRemoveEntry,
          onPressed: onRemove,
        ),
      ],
    );

    return SizedBox(
      height: playlistEntryExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Opacity(
          opacity: track == null ? 0.6 : 1,
          child: QueueActionsRegion(
            onAction: onQueueAction,
            child: Material(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: row),
            ),
          ),
        ),
      ),
    );
  }
}
