import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../l10n/l10n.dart';
import '../album_artist_label.dart';
import 'album_artwork.dart';
import 'queue_actions_menu.dart';

/// One album row: artwork, title, "artist · year · N songs".
class AlbumListTile extends StatelessWidget {
  const AlbumListTile({
    super.key,
    required this.album,
    required this.onTap,
    this.onQueueAction,
  });

  final AlbumSummary album;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = [
      albumArtistLabel(
        l10n,
        artist: album.artist,
        variousArtists: album.variousArtists,
      ),
      if (album.year != null) '${album.year}',
      l10n.albumsSongCount(album.trackCount),
    ].join(' · ');

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: AlbumArtwork(
        albumKey: album.key,
        coverKey: album.coverKey,
        size: 48,
      ),
      title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
