import 'package:go_router/go_router.dart';

import '../../core/database/home_windows.dart';
import '../../l10n/l10n.dart';
import 'home_album_grid_screen.dart';
import 'home_artist_grid_screen.dart';
import 'home_paged_providers.dart';
import 'home_recently_added_screen.dart';
import 'home_track_list_screen.dart';

/// Pages below Home (`/home/...`). The router mounts them under the Home
/// branch, so their paths are relative, never starting with `/`.
final homeRoutes = <RouteBase>[
  GoRoute(
    path: 'recently-added',
    builder: (context, state) => HomeRecentlyAddedScreen(
      // An unknown or missing value falls back to the window in effect.
      initialWindow: HomeAddedWindow.fromSlug(
        state.uri.queryParameters['window'],
      ),
    ),
  ),
  GoRoute(
    path: 'memories',
    builder: (context, state) => HomeTrackListScreen(
      title: context.l10n.homeMemoriesTitle,
      emptyText: context.l10n.homeMemoriesEmpty,
      pages: homeMemoriesPagesProvider,
    ),
  ),
  GoRoute(
    path: 'recent-albums',
    builder: (context, state) => const HomeAlbumGridScreen(),
  ),
  GoRoute(
    path: 'recent-artists',
    builder: (context, state) => const HomeArtistGridScreen(),
  ),
];
