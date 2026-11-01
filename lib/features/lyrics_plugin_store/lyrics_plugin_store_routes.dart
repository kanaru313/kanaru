import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../shared/lyrics_source_routes.dart';
import '../../shared/settings_routes.dart';
import '../../shared/translation_plugin_routes.dart';
import 'catalog_item_page.dart';
import 'plugin_store_page.dart';
import 'repositories_page.dart';

/// The plugin store pages mounted at [base] (an absolute location);
/// [path] is [base] relative to its parent route. The page opens on the
/// [initialKind] chip.
///
/// The router mounts the store twice, at [lyricsStoreRoute] and under the
/// sources page at [lyricsSourcesStoreRoute], so each hop into it is a push
/// and back is a pop. In-store hops stay inside the mount they started in.
///
/// Every hop is a `go`: the shell history only records `go` locations, so a
/// push would make the top-bar back skip these pages. The installed plugin's
/// page lives under the sources page (a translate plugin's under Playback
/// settings), so opening it is a `go` there.
GoRoute lyricsStoreRoutesAt({
  required String base,
  required String path,
  PluginKind initialKind = PluginKind.lyrics,
}) => GoRoute(
  path: path,
  builder: (context, state) => PluginStorePage(
    initialKind: initialKind,
    onOpenInstalled: (id, kind) => _openInstalled(context, id, kind),
    onOpenCatalogItem: (repoUrl, slug) => context.go(
      lyricsStoreItemRoute(base: base, repoUrl: repoUrl, slug: slug),
    ),
    onOpenRepositories: () => context.go(lyricsStoreRepositoriesRoute(base)),
  ),
  routes: [
    GoRoute(
      path: lyricsStoreRepositoriesSegment,
      builder: (context, state) => const RepositoriesPage(),
    ),
    GoRoute(
      path: lyricsStoreItemSegment,
      builder: (context, state) => CatalogItemPage(
        // A missing or empty parameter names no item; the page then shows
        // its "not found" state instead of failing.
        repoUrl: state.uri.queryParameters[lyricsStoreItemRepoParam] ?? '',
        slug: state.uri.queryParameters[lyricsStoreItemSlugParam] ?? '',
        onOpenInstalled: (id, kind) => _openInstalled(context, id, kind),
      ),
    ),
  ],
);

/// Opens the page of the plugin installed as [id] by its [kind]: a translate
/// plugin has its own page below Playback settings. A kind this build does not
/// know has no page, so nothing opens.
void _openInstalled(BuildContext context, String id, PluginKind? kind) {
  switch (kind) {
    case PluginKind.translate:
      context.go(translationPluginRoute(id));
    case PluginKind.lyrics:
      context.go(lyricsPluginRoute(id));
    case null:
      break;
  }
}

/// The store mounted under the sources page (route `plugins` below it).
GoRoute lyricsSourcesStoreMount() => lyricsStoreRoutesAt(
  base: lyricsSourcesStoreRoute,
  path: lyricsSourcesStoreRoute.substring('$lyricsSourcesRoute/'.length),
);

/// The store mounted at the root of Settings (route `plugins` below
/// [settingsRoute]).
GoRoute lyricsRootStoreMount() => lyricsStoreRoutesAt(
  base: lyricsStoreRoute,
  path: lyricsStoreRoute.substring('$settingsRoute/'.length),
);

/// The store mounted for translation services (route `translation-plugins`
/// below Playback settings); it opens on the Translate chip.
GoRoute translationStoreMount() => lyricsStoreRoutesAt(
  base: translationPluginsRoute,
  path: translationPluginsRoute.substring('$settingsPlaybackRoute/'.length),
  initialKind: PluginKind.translate,
);
