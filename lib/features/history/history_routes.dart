import 'package:go_router/go_router.dart';

/// Location of the History page.
///
/// The same text as `AppDestination.history.path`, repeated on purpose:
/// features cannot import `app/`. A test keeps the two equal.
const historyPath = '/history';

/// Pages below [historyPath]. The router mounts them under the History
/// branch, so the history feature adds its sub-pages here without touching
/// `app/`. Their paths are relative to [historyPath] (`'foo'`, `':id'`), never
/// absolute: go_router rejects a leading `/` on a nested route.
const List<RouteBase> historyRoutes = [];
