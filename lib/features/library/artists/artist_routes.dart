import 'package:go_router/go_router.dart';

import '../albums/album_routes.dart';
import 'artist_albums_screen.dart';
import 'artist_screen.dart';

/// The full list of one album section of an artist, and the album opened
/// from it.
GoRoute _albumsRoute(String path, ArtistAlbumSection section) => GoRoute(
  path: path,
  builder: (context, state) => ArtistAlbumsScreen(
    routeKey: state.pathParameters['key']!,
    section: section,
  ),
  routes: [albumChildRoute()],
);

/// Sub-routes of the Artists branch: an artist page (`/artists/:key`), its
/// full album lists (`albums`, `appears-on`) and the album opened from the
/// page or from a list. The router wires this list under
/// `AppDestination.artists`.
final artistRoutes = <RouteBase>[
  GoRoute(
    path: ':key',
    builder: (context, state) =>
        ArtistScreen(routeKey: state.pathParameters['key']!),
    routes: [
      albumChildRoute(),
      _albumsRoute('albums', ArtistAlbumSection.albums),
      _albumsRoute('appears-on', ArtistAlbumSection.appearsOn),
    ],
  ),
];
