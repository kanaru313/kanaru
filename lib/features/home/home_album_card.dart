import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show AlbumSummary;
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/widgets/album_artwork.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'home_tile_metrics.dart';

/// One album on a shelf: square artwork, title, "artist · year". Tapping
/// opens the album page. Copied from AlbumGridTile in album_grid_tile.dart.
class HomeAlbumCard extends ConsumerWidget {
  const HomeAlbumCard({super.key, required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle = [
      album.artist ?? context.l10n.albumsUnknownArtist,
      if (album.year != null) '${album.year}',
    ].join(' · ');
    final tile = InkWell(
      onTap: () => context.go(albumLocation(album.key)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(homeCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArtwork(
              albumKey: album.key,
              coverKey: album.coverKey,
              size: homeCardPictureSize,
            ),
            const SizedBox(height: homeCardGap),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return QueueActionsRegion(
      onAction: (action) =>
          enqueueAlbum(ref, context, action, album.key, album.title),
      child: tile,
    );
  }
}
