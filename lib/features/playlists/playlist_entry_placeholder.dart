import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/song_tile_placeholder.dart';
import 'playlist_entry_handle.dart';

/// The slot of an entry that is not read yet: as tall as a real row so the
/// list does not jump when the row arrives, with no handle and no actions,
/// so it cannot be tapped or dragged. Its cover lines up with the covers of
/// rows that start with a handle.
class PlaylistEntryPlaceholder extends StatelessWidget {
  const PlaylistEntryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const SongTilePlaceholder(leadingInset: playlistEntryHandleWidth);
}
