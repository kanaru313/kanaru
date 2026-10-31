import 'package:material_ui/material_ui.dart';

import '../favorite_button.dart';

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
