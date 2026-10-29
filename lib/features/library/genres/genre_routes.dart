import 'package:go_router/go_router.dart';

import '../albums/album_routes.dart';
import 'genre_albums_screen.dart';
import 'genre_screen.dart';

/// Sub-routes of the Genres branch: a genre page (`/genres/:key`), its full
/// album list (`albums`) and the album opened from either. The router wires
/// this list under `AppDestination.genres`.
final genreRoutes = <RouteBase>[
  GoRoute(
    path: ':key',
    builder: (context, state) =>
        GenreScreen(routeKey: state.pathParameters['key']!),
    routes: [
      albumChildRoute(),
      GoRoute(
        path: 'albums',
        builder: (context, state) =>
            GenreAlbumsScreen(routeKey: state.pathParameters['key']!),
        routes: [albumChildRoute()],
      ),
    ],
  ),
];
