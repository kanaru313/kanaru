import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/home/home_screen.dart';
import '../features/library/library_section_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/l10n.dart';
import 'shell/app_destination.dart';
import 'shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppDestination.home.path,
    routes: [
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
    AppDestination.songs ||
    AppDestination.albums ||
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
