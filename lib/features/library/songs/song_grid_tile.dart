import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/track_actions_menu.dart';
import '../albums/album_grid_tile.dart';

/// One song in the Songs grid: square cover, title and artist, with the same
/// tap and menu as a song row.
class SongGridTile extends ConsumerWidget {
  const SongGridTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onQueueAction,
  });

  final TrackListItem song;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// Same shape as an album tile: the square cover and two text lines at the
  /// current text scale.
  static double heightFor(BuildContext context, double width) =>
      AlbumGridTile.heightFor(context, width);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artist = song.artist;
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(gridTilePadding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArt(
                path: coverPath(
                  ref.watch(coverCacheDirectoryProvider),
                  song.coverKey,
                ),
                size: constraints.maxWidth,
                placeholder: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(AppIcons.musicNoteOutlined, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: gridTileGap),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return TrackActionsRegion(
      trackId: song.id,
      path: song.path,
      hasArtist: artist?.isNotEmpty ?? false,
      hasAlbum: song.album?.isNotEmpty ?? false,
      onQueueAction: onQueueAction,
      child: tile,
    );
  }
}

/// A grid tile whose song is still being read: the cover's square in the
/// placeholder color, nothing else, so the grid does not jump when it loads.
class SongGridTilePlaceholder extends StatelessWidget {
  const SongGridTilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.all(gridTilePadding),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: constraints.maxWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid layout of the Songs grid in a [width] wide area.
SliverGridDelegate songGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: SongGridTile.heightFor);
