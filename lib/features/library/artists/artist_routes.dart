import 'package:go_router/go_router.dart';

import '../albums/album_routes.dart';
import 'artist_screen.dart';

/// Sub-routes of the Artists branch: an artist page (`/artists/:key`) and the
/// album opened from it. The router wires this list under
/// `AppDestination.artists`.
final artistRoutes = <RouteBase>[
  GoRoute(
    path: ':key',
    builder: (context, state) =>
        ArtistScreen(routeKey: state.pathParameters['key']!),
    routes: [albumChildRoute()],
  ),
];
