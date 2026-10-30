/// Paths of the lyrics source screens. Constants and builders only; the
/// router that serves them lives in `lib/app/`.
library;

/// The list of lyrics sources (LRCLIB and installed plugins).
const lyricsSourcesRoute = '/settings/lyrics-sources';

/// Name of the path parameter of [lyricsPluginRoutePattern].
const lyricsPluginIdParam = 'installId';

/// The route pattern of one installed plugin's detail screen.
const lyricsPluginRoutePattern =
    '$lyricsSourcesRoute/plugin/:$lyricsPluginIdParam';

/// The plugin store.
const lyricsStoreRoute = '$lyricsSourcesRoute/store';

/// The list of plugin repositories.
const lyricsStoreRepositoriesRoute = '$lyricsStoreRoute/repositories';

/// The route pattern of one store item (it takes the `repo` and `slug`
/// query parameters).
const lyricsStoreItemRoutePattern = '$lyricsStoreRoute/item';

/// Query parameter names of [lyricsStoreItemRoutePattern].
const lyricsStoreItemRepoParam = 'repo';
const lyricsStoreItemSlugParam = 'slug';

/// The detail screen of the plugin installed as [installId].
String lyricsPluginRoute(String installId) =>
    '$lyricsSourcesRoute/plugin/${Uri.encodeComponent(installId)}';

/// The store page of the item [slug] of the repository at [repoUrl]; both
/// are encoded, so any character is safe.
String lyricsStoreItemRoute({required String repoUrl, required String slug}) =>
    Uri(
      path: lyricsStoreItemRoutePattern,
      queryParameters: {
        lyricsStoreItemRepoParam: repoUrl,
        lyricsStoreItemSlugParam: slug,
      },
    ).toString();
