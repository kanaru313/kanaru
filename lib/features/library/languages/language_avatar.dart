import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/placeholder_colors.dart';

/// Round placeholder for a language: the language icon on a color picked from
/// [languageKey], the same on every launch. Same look as `ArtistAvatar`.
class LanguageAvatar extends StatelessWidget {
  const LanguageAvatar({
    super.key,
    required this.languageKey,
    required this.size,
  });

  final String languageKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      languageKey,
    );
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Icon(AppIcons.language, size: size * 0.45),
    );
  }
}
