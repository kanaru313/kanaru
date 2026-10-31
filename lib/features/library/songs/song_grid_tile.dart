import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/playing_track_path.dart';
import '../../../shared/fixed_line_strut.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/track_actions_menu.dart';
import '../albums/album_grid_tile.dart';
import '../widgets/library_grid_card.dart';
import 'song_grid_tile_parts.dart';

export 'song_grid_tile_parts.dart' show SongGridTilePlaceholder;

/// One song in the Songs grid: a rounded card with the square cover (a heart
/// on its corner), the title, the artist and "Album • length". Tap plays;
/// the menu is the one of a song row.
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

  /// Height of a tile whose cover is [width] wide: the cover, the gap, three
  /// text lines at the current text scale, the card's extra bottom padding
  /// and a little slack. Lines are rounded to whole pixels like the struts
  /// the tile draws.
  static double heightFor(BuildContext context, double width) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) =>
        (scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1))
            .roundToDouble();

    return width +
        gridTileGap +
        line(theme.titleSmall) +
        2 * line(theme.bodySmall) +
        (libraryGridCardBottomPadding - libraryGridCardPadding) +
        // Rounding slack so a fractional line height never clips.
        2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playing = ref.watch(
      playingTrackPathProvider.select((p) => p == song.path),
    );
    final artist = song.artist;
    final durationMs = song.durationMs;
    final detail = joinRowDetails([
      song.album,
      if (durationMs != null)
        formatDuration(Duration(milliseconds: durationMs)),
    ]);
    final titleColor = playing ? colors.onPrimaryContainer : null;
    final detailColor = playing
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final card = LibraryGridCard(
      playing: playing,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverArt(
                  path: coverPath(
                    ref.watch(coverCacheDirectoryProvider),
                    song.coverKey,
                  ),
                  size: constraints.maxWidth,
                  radius: libraryGridCoverRadius,
                  placeholder: ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(AppIcons.musicNoteOutlined, size: 40),
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: 6,
                  bottom: 6,
                  child: SongGridHeartChip(path: song.path),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: libraryGridTextInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: gridTileGap),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                    strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
                  ),
                  Text(
                    artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: detailColor,
                    ),
                    strutStyle: fixedLineStrut(theme.textTheme.bodySmall),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: detailColor,
                    ),
                    strutStyle: fixedLineStrut(theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return TrackActionsRegion(
      song: song,
      onQueueAction: onQueueAction,
      child: card,
    );
  }
}

/// Grid layout of the Songs grid in a [width] wide area.
SliverGridDelegate songGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: SongGridTile.heightFor);
