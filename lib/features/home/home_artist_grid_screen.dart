import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show ArtistCredit;
import '../../l10n/l10n.dart';
import '../../shared/artist_page/enqueue_artist.dart';
import '../../shared/artist_summaries.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/widgets/library_grid/artist_grid_tile.dart';
import 'home_card_grid_screen.dart';
import 'home_paged_providers.dart';
import 'home_tile_metrics.dart';

/// Every artist played, newest listen first.
class HomeArtistGridScreen extends ConsumerWidget {
  const HomeArtistGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return HomeCardGridScreen<ArtistCredit>(
      title: l10n.homeRecentArtistsTitle,
      emptyText: l10n.homeRecentArtistsEmpty,
      emptyIcon: AppIcons.artistOutline,
      pages: homeRecentArtistsPagesProvider,
      cardBuilder: (artist) => homeArtistTile(context, ref, artist),
      cellHeight: homeShelfTileHeight,
    );
  }
}

/// The library's artist tile for [artist] on Home: tap opens the artist page,
/// right click, long press or the Menu key opens the artist modal.
Widget homeArtistTile(
  BuildContext context,
  WidgetRef ref,
  ArtistCredit artist,
) => ArtistGridTile(
  artist: buildArtistSummaries([artist]).single,
  onTap: () => context.go(artistLocation(artist.key)),
  onQueueAction: (action) =>
      enqueueArtist(ref, context, action, artist.key, artist.name),
);
