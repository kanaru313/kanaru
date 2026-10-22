import 'package:go_router/go_router.dart';

import 'history_track_screen.dart';

/// Location of the History page.
///
/// The same text as `AppDestination.history.path`, repeated on purpose:
/// features cannot import `app/`. A test keeps the two equal.
const historyPath = '/history';

/// Location of the history page of the song at [path].
///
/// The path travels as a query parameter: `Uri` percent-encodes every
/// character that would break the location (`+`, `%`, `#`, `?`, `&`, `=`,
/// spaces, non-ASCII), and the router decodes it back unchanged. It is only
/// ever used to look the song up, never as a playable address.
String historyTrackLocation(String path) =>
    Uri(path: '$historyPath/track', queryParameters: {'path': path}).toString();

/// Pages below [historyPath]. The router mounts them under the History
/// branch, so the history feature adds its sub-pages here without touching
/// `app/`. Their paths are relative to [historyPath] (`'foo'`, `':id'`), never
/// absolute: go_router rejects a leading `/` on a nested route.
final List<RouteBase> historyRoutes = [
  GoRoute(
    path: 'track',
    builder: (context, state) =>
        HistoryTrackScreen(path: state.uri.queryParameters['path']),
  ),
];
