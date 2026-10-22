import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_startup.dart';
import '../core/settings/settings_provider.dart';
import '../features/history/history_routes.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/albums/album_screen.dart';
import '../features/library/albums/albums_screen.dart';
import '../features/library/artists/artist_screen.dart';
import '../features/library/artists/artists_screen.dart';
import '../features/library/folders/folder_screen.dart';
import '../features/library/folders/folders_screen.dart';
import '../features/library/genres/genre_screen.dart';
import '../features/library/genres/genres_screen.dart';
import '../features/library/onboarding/onboarding_screen.dart';
import '../features/library/songs/songs_screen.dart';
import '../features/playlists/favorites_routes.dart';
import '../features/playlists/favorites_screen.dart';
import '../features/playlists/playlist_screen.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell/app_destination.dart';
import 'shell/app_shell.dart';
import 'shell/missing_roots_notice.dart';

/// First-run source picker, outside the shell (no sidebar or player bar).
const _welcomePath = '/welcome';

/// Whether the first-run picker is done: a folder exists, or the user already
/// added one or chose "Later" (an app whose folders were all removed opens
/// straight to the empty library).
bool _onboarded(Ref ref) =>
    ref.read(settingsProvider).libraryOnboarded ||
    ref.read(libraryHasRootsProvider);

final routerProvider = Provider<GoRouter>((ref) {
  // Read once: the first-run screen only matters when the app opens. Without
  // a database the library is unavailable and there is nothing to set up.
  final showWelcome =
      ref.read(libraryDatabaseProvider) != null && !_onboarded(ref);
  final router = GoRouter(
    initialLocation: showWelcome ? _welcomePath : AppDestination.home.path,
    routes: [
      GoRoute(
        path: _welcomePath,
        // Back or a typed URL must not return to onboarding once a folder
        // exists.
        redirect: (context, state) =>
            _onboarded(ref) ? AppDestination.home.path : null,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MissingRootsNotice(
          child: AppShell(navigationShell: navigationShell),
        ),
        branches: [
          for (final destination in AppDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) => _buildPage(state, destination),
                  routes: switch (destination) {
                    AppDestination.albums => [
                      GoRoute(
                        path: ':key',
                        builder: (context, state) =>
                            AlbumScreen(routeKey: state.pathParameters['key']!),
                      ),
                    ],
                    AppDestination.artists => [
                      GoRoute(
                        path: ':key',
                        builder: (context, state) => ArtistScreen(
                          routeKey: state.pathParameters['key']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'album/:albumKey',
                            builder: (context, state) => AlbumScreen(
                              routeKey: state.pathParameters['albumKey']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                    AppDestination.genres => [
                      GoRoute(
                        path: ':key',
                        builder: (context, state) =>
                            GenreScreen(routeKey: state.pathParameters['key']!),
                      ),
                    ],
                    AppDestination.folders => [
                      GoRoute(
                        path: ':key',
                        builder: (context, state) {
                          final key = state.pathParameters['key']!;
                          // A new key is a new page: nothing of the folder
                          // before it stays.
                          return FolderScreen(
                            key: ValueKey(key),
                            routeKey: key,
                          );
                        },
                      ),
                    ],
                    AppDestination.favorites => favoritesRoutes,
                    AppDestination.history => historyRoutes,
                    AppDestination.playlists => [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => PlaylistScreen(
                          routeId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                    _ => const [],
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

Widget _buildPage(GoRouterState state, AppDestination destination) {
  return switch (destination) {
    AppDestination.home => const HomeScreen(),
    AppDestination.songs => const SongsScreen(),
    AppDestination.albums => const AlbumsScreen(),
    AppDestination.artists => const ArtistsScreen(),
    AppDestination.genres => const GenresScreen(),
    AppDestination.folders => const FoldersScreen(),
    AppDestination.favorites => const FavoritesScreen(),
    AppDestination.history => const HistoryScreen(),
    AppDestination.playlists => const PlaylistsScreen(),
    AppDestination.search => SearchScreen(
      query: state.uri.queryParameters['q'] ?? '',
    ),
    AppDestination.settings => const SettingsScreen(),
  };
}
