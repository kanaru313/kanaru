import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_startup.dart';
import '../features/home/home_screen.dart';
import '../features/library/albums/album_screen.dart';
import '../features/library/albums/albums_screen.dart';
import '../features/library/library_section_screen.dart';
import '../features/library/onboarding/onboarding_screen.dart';
import '../features/library/songs/songs_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/l10n.dart';
import 'shell/app_destination.dart';
import 'shell/app_shell.dart';

/// First-run source picker, outside the shell (no sidebar or player bar).
const _welcomePath = '/welcome';

final routerProvider = Provider<GoRouter>((ref) {
  // Read once: the first-run screen only matters when the app opens. Without
  // a database the library is unavailable and there is nothing to set up.
  final showWelcome =
      ref.read(libraryDatabaseProvider) != null &&
      !ref.read(libraryHasRootsProvider);
  return GoRouter(
    initialLocation: showWelcome ? _welcomePath : AppDestination.home.path,
    routes: [
      GoRoute(
        path: _welcomePath,
        // Back or a typed URL must not return to onboarding once a folder
        // exists.
        redirect: (context, state) =>
            ref.read(libraryHasRootsProvider) ? AppDestination.home.path : null,
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
                    _ => const [],
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );
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
    AppDestination.artists ||
    AppDestination.folders => section(l10n.libraryEmptyMessage),
    AppDestination.favorites => section(
      l10n.favoritesEmptyMessage,
      emptyTitle: l10n.navFavorites,
    ),
    AppDestination.recentlyPlayed => section(
      l10n.recentlyPlayedEmptyMessage,
      emptyTitle: l10n.navRecentlyPlayed,
    ),
    AppDestination.search => SearchScreen(
      query: state.uri.queryParameters['q'] ?? '',
    ),
    AppDestination.settings => const SettingsScreen(),
  };
}
