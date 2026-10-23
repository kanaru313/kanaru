import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart' show unknownGenreKey;
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
      // The tracks with no genre get the outlined icon.
      child: Icon(
        genreKey == unknownGenreKey ? AppIcons.genreOutlined : AppIcons.genre,
        size: size * 0.45,
      ),
    );
  }
}
