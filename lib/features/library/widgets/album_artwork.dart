import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show AlbumKey;
import 'stable_hash.dart';

/// Square cover of an album. A colored placeholder for now: the color is
/// picked from the album key, so an album keeps its color across launches.
/// Real covers will replace the inside of this widget only.
class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.albumKey, required this.size});

  final AlbumKey albumKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pairs = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    final (background, foreground) =
        pairs[fnv1a('${albumKey.artistKey}\u0000${albumKey.titleKey}') %
            pairs.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(size < 64 ? 4 : 8),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: background,
          child: Icon(Icons.album, size: size * 0.4, color: foreground),
        ),
      ),
    );
  }
}
