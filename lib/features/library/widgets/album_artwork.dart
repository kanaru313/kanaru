import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show AlbumKey;
import 'placeholder_colors.dart';

/// Square cover of an album. A colored placeholder for now: the color is
/// picked from the album key, so an album keeps its color across launches.
/// Real covers will replace the inside of this widget only.
class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.albumKey, required this.size});

  final AlbumKey albumKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      '${albumKey.artistKey}\u0000${albumKey.titleKey}',
    );

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
