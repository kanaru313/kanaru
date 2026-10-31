import 'package:go_router/go_router.dart';

import '../../shared/lyrics_source_routes.dart';
import 'lyrics_sources_page.dart';
import 'plugin_detail_page.dart';

/// Pages below `/settings`: the sources list and, inside it, the page of one
/// installed plugin. Relative paths (go_router rejects a leading `/` on a
/// nested route); joined they are [lyricsSourcesRoute] and
/// [lyricsPluginRoutePattern], which a test keeps equal.
final List<RouteBase> lyricsSourcesRoutes = lyricsSourcesRoutesWith();

/// [lyricsSourcesRoutes] with [children] nested under the sources page, next
/// to the plugin page. The app's router passes the plugin store's pages here:
/// this feature does not know the store.
List<RouteBase> lyricsSourcesRoutesWith({
  List<RouteBase> children = const [],
}) => [
  GoRoute(
    path: lyricsSourcesRoute.substring('/settings/'.length),
    builder: (context, state) => const LyricsSourcesPage(),
    routes: [
      GoRoute(
        path: 'plugin/:$lyricsPluginIdParam',
        builder: (context, state) => PluginDetailPage(
          installId: state.pathParameters[lyricsPluginIdParam]!,
        ),
      ),
      ...children,
    ],
  ),
];
