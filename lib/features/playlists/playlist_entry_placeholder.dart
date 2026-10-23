import 'package:material_ui/material_ui.dart';

import 'playlist_entry_tile.dart';

/// The slot of an entry that is not read yet: as tall as a real row so the
/// list does not jump when the row arrives, with no handle and no actions,
/// so it cannot be tapped or dragged.
class PlaylistEntryPlaceholder extends StatelessWidget {
  const PlaylistEntryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: playlistEntryExtent,
      child: Padding(
        padding: playlistEntryInset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
