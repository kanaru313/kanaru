import 'package:go_router/go_router.dart';

import 'album_screen.dart';

/// The album page opened from the page above it (`album/:albumKey`), so the
/// album stays in the branch it was opened from and Back returns there.
GoRoute albumChildRoute() => GoRoute(
  path: 'album/:albumKey',
  builder: (context, state) =>
      AlbumScreen(routeKey: state.pathParameters['albumKey']!),
);
