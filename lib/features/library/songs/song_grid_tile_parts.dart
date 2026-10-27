import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/favorite_button.dart';
import '../../../shared/widgets/song_card.dart';

/// Space between the edge of a grid cell and its card (half of the 8 px
/// between two cards).
const songGridCardMargin = 4.0;

/// Space between a card's edge and its cover, above and at the sides.
const songGridCardPadding = 4.0;

/// Space under the text of a card.
const songGridCardBottomPadding = 8.0;

/// Corner radius of the cover: the card's radius less its padding, so the
/// two curves are concentric.
const songGridCoverRadius = 8.0;

/// A grid cell's card: [songGridCardMargin] around, a [songCardColor] fill,
/// and [child] inside the card's padding. The `Material` is always present,
/// so the tree does not change when [playing] flips. [onTap] null draws no
/// ink (the placeholder).
class SongGridCard extends StatelessWidget {
  const SongGridCard({
    super.key,
    required this.child,
    this.playing = false,
    this.onTap,
  });

  final Widget child;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(
        songGridCardPadding,
        songGridCardPadding,
        songGridCardPadding,
        songGridCardBottomPadding,
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.all(songGridCardMargin),
      child: Material(
        color: songCardColor(Theme.of(context).colorScheme, playing: playing),
        shape: songCardShape,
        child: onTap == null
            ? padded
            : InkWell(onTap: onTap, customBorder: songCardShape, child: padded),
      ),
    );
  }
}

/// The heart on a cover's corner, on a translucent theme surface so it reads
/// over any picture. Its colour follows the chip, not the card.
class SongGridHeartChip extends StatelessWidget {
  const SongGridHeartChip({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: FavoriteButton(path: path, compact: true, iconSize: 18),
    ),
  );
}

/// A grid tile whose song is still being read: the card with the cover's
/// square in the placeholder colour, so the grid does not jump when it loads.
class SongGridTilePlaceholder extends StatelessWidget {
  const SongGridTilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SongGridCard(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: constraints.maxWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(songGridCoverRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
