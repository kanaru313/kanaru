import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../album_artist_label.dart';
import '../../fixed_line_strut.dart';
import '../album_artwork.dart';
import '../queue_actions_menu.dart';
import 'album_tile_data.dart';
import 'library_grid_card.dart';

/// One album in a grid: a rounded card with the square artwork, the title and
/// "artist · year", like [SongGridTile] without the heart.
class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({
    super.key,
    required this.data,
    required this.onTap,
    this.onQueueAction,
  });

  final AlbumTileData data;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// Height of a tile whose artwork is [width] wide: the artwork, the gap, two
  /// text lines at the current text scale and the card's extra bottom padding,
  /// so large text never overflows.
  static double heightFor(BuildContext context, double width) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final size = style?.fontSize ?? 14;
      return scaler.scale(size) * (style?.height ?? 1.2);
    }

    return width +
        gridTileGap +
        line(theme.titleSmall) +
        line(theme.bodySmall) +
        (libraryGridCardBottomPadding - libraryGridCardPadding) +
        // Rounding slack so a fractional line height never clips.
        2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subtitle = [
      albumArtistLabel(
        l10n,
        artist: data.artist,
        variousArtists: data.variousArtists,
      ),
      if (data.year != null) '${data.year}',
    ].join(' · ');

    final tile = LibraryGridCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArtwork(
              albumKey: data.key,
              coverKey: data.coverKey,
              size: constraints.maxWidth,
              radius: libraryGridCoverRadius,
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
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
