import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_startup.dart';
import '../core/settings/settings_provider.dart';
import '../features/home/home_screen.dart';
import '../features/library/albums/album_screen.dart';
import '../features/library/albums/albums_screen.dart';
import '../features/library/artists/artist_screen.dart';
import '../features/library/artists/artists_screen.dart';
import '../features/library/library_section_screen.dart';
import '../features/library/onboarding/onboarding_screen.dart';
import '../features/library/songs/songs_screen.dart';
import '../features/playlists/playlist_screen.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/l10n.dart';
import 'shell/app_destination.dart';
import 'shell/app_shell.dart';

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
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final destination in AppDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) =>
                      _buildPage(context, state, destination),
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

Widget _buildPage(
  BuildContext context,
  GoRouterState state,
  AppDestination destination,
) {
  final l10n = context.l10n;

  LibrarySectionScreen section(String emptyMessage, {String? emptyTitle}) =>
      LibrarySectionScreen(
        title: destination.label(l10n),
        icon: destination.icon,
        emptyTitle: emptyTitle ?? l10n.libraryEmptyTitle,
        emptyMessage: emptyMessage,
      );

  return switch (destination) {
    AppDestination.home => const HomeScreen(),
    AppDestination.songs => const SongsScreen(),
    AppDestination.albums => const AlbumsScreen(),
    AppDestination.artists => const ArtistsScreen(),
    AppDestination.folders => section(l10n.libraryEmptyMessage),
    AppDestination.favorites => section(
      l10n.favoritesEmptyMessage,
      emptyTitle: l10n.navFavorites,
    ),
    AppDestination.recentlyPlayed => section(
      l10n.recentlyPlayedEmptyMessage,
      emptyTitle: l10n.navRecentlyPlayed,
    ),
    AppDestination.playlists => const PlaylistsScreen(),
    AppDestination.search => SearchScreen(
      query: state.uri.queryParameters['q'] ?? '',
    ),
    AppDestination.settings => const SettingsScreen(),
  };
}
