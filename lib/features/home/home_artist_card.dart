import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_queries.dart';
import '../../core/database/library_database.dart' show ArtistCredit;
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/artist_avatar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'home_tile_metrics.dart';

/// One artist on a shelf: round avatar, name, "N songs". Tapping opens the
/// artist page. Copied from RoundGridTile in round_grid_tile.dart and
/// ArtistGridTile in artist_grid_tile.dart.
class HomeArtistCard extends ConsumerWidget {
  const HomeArtistCard({super.key, required this.artist});

  final ArtistCredit artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tile = InkWell(
      onTap: () => context.go(artistLocation(artist.key)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(homeCardPadding),
        child: Column(
          children: [
            SizedBox.square(
              dimension: homeCardPictureSize,
              child: Center(
                child: ArtistAvatar(
                  artistKey: artist.key,
                  name: artist.name,
                  size: homeCardPictureSize,
                ),
              ),
            ),
            const SizedBox(height: homeCardGap),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              context.l10n.albumsSongCount(artist.trackCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return QueueActionsRegion(
      onAction: (action) => enqueueFromDatabase(
        ref,
        context,
        action,
        artist.name,
        (db, covers) async => [
          for (final t in await db.artistTracks(artist.key))
            trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
        ],
      ),
      child: tile,
    );
  }
}
