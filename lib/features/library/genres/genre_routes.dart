import 'package:go_router/go_router.dart';

import 'genre_screen.dart';

/// Sub-routes of the Genres branch (`/genres/:key`). The router wires this
/// list under `AppDestination.genres`.
final genreRoutes = <RouteBase>[
  GoRoute(
    path: ':key',
    builder: (context, state) =>
        GenreScreen(routeKey: state.pathParameters['key']!),
  ),
];
