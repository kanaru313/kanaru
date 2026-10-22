import 'package:go_router/go_router.dart';

/// Location of the Favorites page.
///
/// The same text as `AppDestination.favorites.path`, repeated on purpose:
/// features cannot import `app/`. A test keeps the two equal.
const favoritesPath = '/favorites';

/// Pages below [favoritesPath]. The router mounts them under the Favorites
/// branch, so the playlists feature adds its sub-pages here without touching
/// `app/`.
const List<RouteBase> favoritesRoutes = [];
