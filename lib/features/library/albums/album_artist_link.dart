import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/hover_underline_links.dart';

/// The album artist's name, opening their page (in the Artists branch).
class AlbumArtistLink extends StatelessWidget {
  const AlbumArtistLink({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverUnderlineLinks(
      segments: [LinkSegment(name, onTap: (_) => onTap())],
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}
