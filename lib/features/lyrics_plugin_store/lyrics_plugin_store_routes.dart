import 'package:go_router/go_router.dart';

import '../../shared/lyrics_source_routes.dart';
import 'catalog_item_page.dart';
import 'plugin_store_page.dart';
import 'repositories_page.dart';

/// Pages of the plugin store, to nest under the lyrics sources route (the
/// app's router composes them in, so back goes store -> sources). Relative
/// paths; joined with the sources route they are [lyricsStoreRoute],
/// [lyricsStoreRepositoriesRoute] and [lyricsStoreItemRoutePattern], which a
/// test keeps equal.
///
/// Every hop is a `go`: the shell history only records `go` locations, so a
/// push would make the top-bar back skip these pages. The
/// catalog item page opens the installed plugin's page when the
/// plugin is already installed.
final List<RouteBase> lyricsStoreRoutes = [
  GoRoute(
    path: lyricsStoreRoute.substring('$lyricsSourcesRoute/'.length),
    builder: (context, state) => PluginStorePage(
      onOpenInstalled: (id) => context.go(lyricsPluginRoute(id)),
      onOpenCatalogItem: (repoUrl, slug) =>
          context.go(lyricsStoreItemRoute(repoUrl: repoUrl, slug: slug)),
      onOpenRepositories: () => context.go(lyricsStoreRepositoriesRoute),
    ),
    routes: [
      GoRoute(
        path: lyricsStoreRepositoriesRoute.substring(
          '$lyricsStoreRoute/'.length,
        ),
        builder: (context, state) => const RepositoriesPage(),
      ),
      GoRoute(
        path: lyricsStoreItemRoutePattern.substring(
          '$lyricsStoreRoute/'.length,
        ),
        builder: (context, state) => CatalogItemPage(
          // A missing or empty parameter names no item; the page then shows
          // its "not found" state instead of failing.
          repoUrl: state.uri.queryParameters[lyricsStoreItemRepoParam] ?? '',
          slug: state.uri.queryParameters[lyricsStoreItemSlugParam] ?? '',
          onOpenInstalled: (id) => context.go(lyricsPluginRoute(id)),
        ),
      ),
    ],
  ),
];
