/// Paths of the Online screen. Constants and builders only; the router that
/// serves them lives in `lib/app/`.
library;

/// The Online screen (search in a source plugin).
const onlineRoute = '/online';

/// Name of the path parameter of [onlineSourcePluginRoutePattern].
const onlineSourcePluginIdParam = 'id';

/// The route pattern of a source plugin's page, a child of [onlineRoute].
const onlineSourcePluginRoutePattern = 'plugin/:$onlineSourcePluginIdParam';

/// The page of the source plugin installed as [installId], a page below the
/// Online screen so that back from it is a pop.
String onlineSourcePluginRoute(String installId) =>
    '$onlineRoute/plugin/${Uri.encodeComponent(installId)}';
