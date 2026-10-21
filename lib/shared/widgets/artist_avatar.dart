import 'package:material_ui/material_ui.dart';

import 'placeholder_colors.dart';

/// Round placeholder for an artist: the first letter of [name] on a color
/// picked from [artistKey], the same on every launch. Artist pictures will
/// replace the inside of this widget only.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    required this.artistKey,
    required this.name,
    required this.size,
  });

  final String artistKey;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      artistKey,
    );
    final initial = name.characters.firstOrNull?.toUpperCase() ?? '';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.4),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
