import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/favorite_button.dart';
import '../widgets/library_grid_card.dart';

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
    return LibraryGridCard(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: constraints.maxWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(libraryGridCoverRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
