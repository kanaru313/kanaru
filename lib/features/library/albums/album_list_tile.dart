import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../widgets/album_artwork.dart';

/// One album in the list view: artwork, title, "artist · year · N songs".
class AlbumListTile extends StatelessWidget {
  const AlbumListTile({super.key, required this.album, required this.onTap});

  final AlbumSummary album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = [
      album.artist ?? l10n.albumsUnknownArtist,
      if (album.year != null) '${album.year}',
      l10n.albumsSongCount(album.trackCount),
    ].join(' · ');

    return ListTile(
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
  }
}
