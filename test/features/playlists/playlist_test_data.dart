import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/playlist_details.dart';
import 'package:kanaru/shared/icons/app_icons.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
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

/// Titles of the playlist rows on screen, top to bottom.
List<String> shownTitles(WidgetTester tester) {
  final byY = {
    for (final tile in tester.widgetList<PlaylistEntryTile>(
      find.byType(PlaylistEntryTile),
    ))
      tester.getTopLeft(find.byWidget(tile)).dy:
          tile.entry.track?.title ?? tile.entry.path,
  };
  return [for (final y in byY.keys.toList()..sort()) byY[y]!];
}

/// Titles of the playlist "Mix" that [openMix] seeds.
const mixTitles = ['Alpha', 'Bravo', 'Charlie', 'Delta'];

/// Opens the app on the page of a new playlist "Mix" holding [mixTitles].
Future<int> openMix(WidgetTester tester, LibraryHarness h) async {
  await openApp(tester, h, mixTitles);
  final id = await seedPlaylist(tester, h, 'Mix', mixTitles);
  goTo(tester, h, '/playlists/$id');
  await settleDb(tester);
  return id;
}

/// Pumps frames, letting database work run in between, until [done] is true
/// (checked inside `runAsync`), calling [onFrame] after each frame. Fails
/// when [done] has not become true within [timeout] of wall time, so a test
/// can never pass because the work it waits for did not happen.
Future<void> pumpUntil(
  WidgetTester tester,
  Future<bool> Function() done, {
  void Function()? onFrame,
  Duration frame = const Duration(milliseconds: 16),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final watch = Stopwatch()..start();
  while (true) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(frame);
    onFrame?.call();
    if (await tester.runAsync(done) ?? false) return;
    if (watch.elapsed > timeout) fail('Not done after $timeout');
  }
}

/// Makes every later [event] (`UPDATE`, `DELETE`) on [table] fail inside
/// SQLite, like a full disk.
Future<void> breakWrites(
  WidgetTester tester,
  LibraryHarness h,
  String table,
  String event,
) async {
  await tester.runAsync(
    () => h.db.customStatement(
      'CREATE TRIGGER broken_${table}_$event BEFORE $event ON $table '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    ),
  );
}

/// Drags the first playlist row by its handle just below the third, without
/// waiting for the result.
Future<void> dragFirstRowDown(WidgetTester tester) async {
  final handle = find.byIcon(AppIcons.dragHandle).first;
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 18; i++) {
    await gesture.moveBy(const Offset(0, 8));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

/// Height of a playlist row (all rows share the list's prototype height).
double rowExtent(WidgetTester tester) =>
    tester.getSize(find.byType(PlaylistEntryTile).first).height;

/// Moves a mouse pointer over row [index] so its hover-only actions show.
Future<TestGesture> hoverRow(WidgetTester tester, int index) =>
    hoverOn(tester, find.byType(PlaylistEntryTile).at(index));

final _mice = Expando<TestGesture>('hovering mouse');

/// Moves the test's mouse pointer over the middle of [target].
Future<TestGesture> hoverOn(WidgetTester tester, Finder target) async {
  var gesture = _mice[tester];
  if (gesture == null) {
    gesture = _mice[tester] = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
  }
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  return gesture;
}

/// The song count in the details of a playlist page (header or side pane).
/// The songs toolbar shows the same count, so a bare `find.text` finds two.
Finder playlistSongCount(String text) => find.descendant(
  of: find.byType(PlaylistDetails),
  matching: find.text(text),
);

/// Removes row [index] the way a user does: opens its song modal with a right
/// click and taps Remove from playlist. Leaves the frame right after the tap.
Future<void> removeRowViaModal(WidgetTester tester, int index) =>
    removeRowOf(tester, find.byType(PlaylistEntryTile).at(index));

/// Same as [removeRowViaModal] for the row [row].
Future<void> removeRowOf(WidgetTester tester, Finder row) async {
  await tester.tap(row, buttons: kSecondaryButton);
  await settleSongModal(tester);
  await tester.tap(find.text('Remove from playlist'));
  await tester.pump();
}

/// Opens the song modal of row [index], checks whether it holds Remove from
/// playlist, and closes it with Esc.
Future<void> expectRowModalRemove(
  WidgetTester tester,
  int index, {
  required bool present,
}) async {
  await tester.tap(
    find.byType(PlaylistEntryTile).at(index),
    buttons: kSecondaryButton,
  );
  await settleSongModal(tester);
  expect(find.text('Go to artist'), findsOneWidget, reason: 'modal is open');
  expect(
    modalAction('remove-from-playlist'),
    present ? findsOneWidget : findsNothing,
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await settleSongModal(tester);
}
