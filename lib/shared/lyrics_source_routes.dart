/// Paths of the lyrics source screens. Constants and builders only; the
/// router that serves them lives in `lib/app/`.
library;

import 'settings_routes.dart';

/// The list of lyrics sources (the installed plugins), a page below
/// Playback settings so that back from it is a pop.
const lyricsSourcesRoute = '$settingsPlaybackRoute/lyrics-sources';

/// Name of the path parameter of [lyricsPluginRoutePattern].
const lyricsPluginIdParam = 'installId';

/// The route pattern of one installed plugin's detail screen.
const lyricsPluginRoutePattern =
    '$lyricsSourcesRoute/plugin/:$lyricsPluginIdParam';

/// The plugin store as mounted at the root of Settings.
///
/// The store is mounted twice (here and under the sources page, see
/// [lyricsSourcesStoreRoute]) so that each hop into it is a push and back is
/// a pop. Pages below a store base: [lyricsStoreRepositoriesRoute] and
/// [lyricsStoreItemRoute].
const lyricsStoreRoute = '$settingsRoute/plugins';

/// The plugin store as mounted under the lyrics sources page.
const lyricsSourcesStoreRoute = '$lyricsSourcesRoute/plugins';

/// Path segment of the repositories page below a store base.
const lyricsStoreRepositoriesSegment = 'repositories';

/// Path segment of a store item page below a store base.
const lyricsStoreItemSegment = 'item';

/// Query parameter names of a store item route.
const lyricsStoreItemRepoParam = 'repo';
const lyricsStoreItemSlugParam = 'slug';

/// The list of plugin repositories of the store mounted at [base].
String lyricsStoreRepositoriesRoute(String base) =>
    '$base/$lyricsStoreRepositoriesSegment';

/// The route pattern of a store item of the store mounted at [base] (it takes
/// the `repo` and `slug` query parameters).
String lyricsStoreItemRoutePatternAt(String base) =>
    '$base/$lyricsStoreItemSegment';

/// The detail screen of the plugin installed as [installId].
String lyricsPluginRoute(String installId) =>
    '$lyricsSourcesRoute/plugin/${Uri.encodeComponent(installId)}';

/// The store page of the item [slug] of the repository at [repoUrl], in the
/// store mounted at [base]; both are encoded, so any character is safe.
String lyricsStoreItemRoute({
  required String base,
  required String repoUrl,
  required String slug,
}) => Uri(
  path: lyricsStoreItemRoutePatternAt(base),
  queryParameters: {
    lyricsStoreItemRepoParam: repoUrl,
    lyricsStoreItemSlugParam: slug,
  },
).toString();
