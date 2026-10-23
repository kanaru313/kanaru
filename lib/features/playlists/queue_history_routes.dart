import 'package:go_router/go_router.dart';

import 'playlist_routes.dart' show parsePlaylistRouteId;
import 'queue_history_snapshot_screen.dart';

/// Location of the queue history page.
///
/// The same text as `AppDestination.queueHistory.path`, repeated on purpose:
/// features cannot import `app/`. A test keeps the two equal.
const queueHistoryPath = '/queue-history';

/// Location of the page of saved queue [id].
String queueHistoryLocation(int id) => '$queueHistoryPath/$id';

/// The saved queue id in a route parameter, read like a playlist id: digits
/// only and above zero, else null.
int? parseQueueHistoryRouteId(String raw) => parsePlaylistRouteId(raw);

/// Pages below [queueHistoryPath], mounted by the router under the queue
/// history branch. Paths are relative (go_router rejects a leading `/` on a
/// nested route).
final List<RouteBase> queueHistoryRoutes = [
  GoRoute(
    path: ':id',
    builder: (context, state) =>
        QueueHistorySnapshotScreen(routeId: state.pathParameters['id']!),
  ),
];
