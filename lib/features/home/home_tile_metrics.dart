import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/library_grid/album_grid_tile.dart';
import '../../shared/widgets/library_grid/library_grid_card.dart';
import '../../shared/widgets/library_grid/song_grid_tile.dart';

/// Padding around the content of an artist card and the gap between the
/// picture and the text.
const homeCardPadding = 8.0;
const homeCardGap = 8.0;

/// Width of a cell on a shelf: 152 px of content plus the padding each side.
const homeShelfTileWidth = 168.0;

/// Width of the square picture of an artist card.
const homeCardPictureSize = homeShelfTileWidth - homeCardPadding * 2;

/// Height of an artist card: the square picture plus two text lines at the
/// current text scale, so large text never overflows.
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

/// Space between a shelf cell's edge and a grid card's content: the card's
/// margin plus its padding.
const homeGridCardInset = libraryGridCardMargin + libraryGridCardPadding;

/// Cover side of a grid card in a shelf cell. Equals [homeCardPictureSize], so
/// `HomeShelf.arrowTop` holds for every shelf.
const homeGridCardCoverSize = homeShelfTileWidth - homeGridCardInset * 2;

/// Height of a shelf of song grid cards at the current text scale.
double homeTrackShelfHeight(BuildContext context) =>
    SongGridTile.heightFor(context, homeGridCardCoverSize) +
    homeGridCardInset * 2;

/// Height of a shelf of album grid cards at the current text scale.
double homeAlbumShelfHeight(BuildContext context) =>
    AlbumGridTile.heightFor(context, homeGridCardCoverSize) +
    homeGridCardInset * 2;

/// An artist card whose data is still being read: the picture's square in the
/// placeholder color, nothing else.
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
