import 'package:material_ui/material_ui.dart';

/// Padding around the content of a shelf card and the gap between the picture
/// and the text; copied from album_grid_tile.dart.
const homeCardPadding = 8.0;
const homeCardGap = 8.0;

/// Width of a card on a shelf: 152 px of content plus the padding each side.
const homeShelfTileWidth = 168.0;

/// Width of the square picture of a card.
const homeCardPictureSize = homeShelfTileWidth - homeCardPadding * 2;

/// Height of a card: the square picture plus two text lines at the current
/// text scale, so large text never overflows. Copied from
/// `AlbumGridTile.heightFor` in album_grid_tile.dart.
double homeShelfTileHeight(BuildContext context) {
  final theme = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle? style) {
    final size = style?.fontSize ?? 14;
    return scaler.scale(size) * (style?.height ?? 1.2);
  }

  return homeCardPictureSize +
      homeCardGap +
      line(theme.titleSmall) +
      line(theme.bodySmall) +
      // Rounding slack so a fractional line height never clips.
      2 +
      homeCardPadding * 2;
}

/// A card whose data is still being read: the picture's square in the
/// placeholder color, nothing else. Copied from `SongGridTilePlaceholder` in
/// song_grid_tile.dart.
class HomeCardPlaceholder extends StatelessWidget {
  const HomeCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.all(homeCardPadding),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.square(
          dimension: homeCardPictureSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
