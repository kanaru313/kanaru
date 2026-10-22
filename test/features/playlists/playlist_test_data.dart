import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';

/// Path of every stored track, by title.
Future<Map<String, String>> trackPaths(
  WidgetTester tester,
  LibraryHarness h,
) async {
  final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
  return {for (final row in rows!) row.title: row.path};
}

/// Creates a playlist named [name] holding the stored tracks titled
/// [titles], in that order, and returns its id. [now] orders playlists
/// (newest first).
Future<int> seedPlaylist(
  WidgetTester tester,
  LibraryHarness h,
  String name,
  List<String> titles, {
  int now = 1,
  List<String> extraPaths = const [],
}) async {
  final paths = await trackPaths(tester, h);
  final id = await tester.runAsync(
    () => h.db.createPlaylist(
      name,
      now: now,
      paths: [for (final title in titles) paths[title]!, ...extraPaths],
    ),
  );
  return id!;
}

/// Entry paths of playlist [id] in stored order.
Future<List<String>> storedPaths(
  WidgetTester tester,
  LibraryHarness h,
  int id,
) async {
  final page = await tester.runAsync(() => h.db.playlistPage(id));
  return [for (final e in page!.entries) e.path];
}

/// Stores tracks titled [titles], opens the app on [location] and returns.
Future<void> openApp(
  WidgetTester tester,
  LibraryHarness h,
  List<String> titles, {
  String location = '/home',
}) => openWithTracks(tester, h, [
  for (final title in titles) TestTrack(title),
], location: location);

/// Lets pending database work and the frames it triggers finish.
Future<void> settleDb(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}
