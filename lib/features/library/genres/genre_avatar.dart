import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/placeholder_colors.dart';

/// Round placeholder for a genre: the genre icon on a color picked from
/// [genreKey], the same on every launch. Same look as `ArtistAvatar`.
class GenreAvatar extends StatelessWidget {
  const GenreAvatar({super.key, required this.genreKey, required this.size});

  final String genreKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      genreKey,
    );
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Icon(AppIcons.genre, size: size * 0.45),
    );
  }
}
