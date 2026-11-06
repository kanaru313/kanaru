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
/// [path] is [base] relative to its parent route. The page preselects
/// [initialKind] in its filters (null lists every kind).
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
  PluginKind? initialKind,
}) => GoRoute(
  path: path,
  builder: (context, state) => PluginStorePage(
    // A `kind` query parameter wins over the mount's own preselection.
    initialKind: _kindOf(state) ?? initialKind,
    onOpenInstalled: (id, kind) => _openInstalled(context, id, kind),
    // The `kind` query is carried into the pages below the store: the store
    // page stays mounted under them and reads it again from the location.
    onOpenCatalogItem: (repoUrl, slug) => context.go(
      _withKind(
        lyricsStoreItemRoute(base: base, repoUrl: repoUrl, slug: slug),
        state,
      ),
    ),
    onOpenRepositories: () =>
        context.go(_withKind(lyricsStoreRepositoriesRoute(base), state)),
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

/// [location] with the `kind` query of [state], when it has one.
String _withKind(String location, GoRouterState state) {
  final kind = state.uri.queryParameters[lyricsStoreKindParam];
  if (kind == null || PluginKind.fromValue(kind) == null) return location;
  final uri = Uri.parse(location);
  return uri
      .replace(
        queryParameters: {...uri.queryParameters, lyricsStoreKindParam: kind},
      )
      .toString();
}

PluginKind? _kindOf(GoRouterState state) {
  final text = state.uri.queryParameters[lyricsStoreKindParam];
  return text == null ? null : PluginKind.fromValue(text);
}

/// Opens the page of the plugin installed as [id] by its [kind]: a translate
/// plugin has its own page below Playback settings. A kind this build does not
/// know has no page, so nothing opens.
void _openInstalled(BuildContext context, String id, PluginKind? kind) {
  switch (kind) {
    case PluginKind.translate:
    case PluginKind.aiTranslate:
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
/// below Playback settings); it preselects Translate.
GoRoute translationStoreMount() => lyricsStoreRoutesAt(
  base: translationPluginsRoute,
  path: translationPluginsRoute.substring('$settingsPlaybackRoute/'.length),
  initialKind: PluginKind.translate,
);
