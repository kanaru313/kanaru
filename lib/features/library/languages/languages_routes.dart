import 'package:go_router/go_router.dart';

import 'language_screen.dart';

/// Sub-routes of the Languages branch (`/languages/:key`). The router wires
/// this list under `AppDestination.languages`.
final languagesRoutes = <RouteBase>[
  GoRoute(
    path: ':key',
    builder: (context, state) =>
        LanguageScreen(routeKey: state.pathParameters['key']!),
  ),
];
