import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';

import '../../core/stats/gated_query_interceptor.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/add_to_playlist_test_support.dart';
import '../playlists/playlist_test_data.dart';
import 'queue_tile_menu_test_support.dart';

const _library = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
  TestTrack('c', artist: 'Ann', album: 'Al'),
];

void main() {
  late LibraryHarness h;
  late GatedQueryInterceptor gate;

  setUp(() {
    gate = GatedQueryInterceptor();
    h = LibraryHarness(refreshInterval: Duration.zero, interceptor: gate);
  });

  PlayerService player() => h.container.read(playerServiceProvider.notifier);

  Future<Map<String, String>> open(
    WidgetTester tester, [
    List<String> titles = const ['a', 'b', 'c'],
  ]) async {
    await openWithTracks(tester, h, _library, location: '/home');
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, h, [
      for (final t in titles) Track(uri: p[t]!, title: t),
    ]);
    return p;
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settleDb(tester);
  }

  testWidgets('Play next moves the track without a copy', (tester) async {
    await open(tester);
    await openQueueMenu(tester, 'c');
    await pick(tester, 'Play next');

    expect(queueTitles(h), ['a', 'c', 'b']);
    expect(player().upNextRun, 1);
  });

  testWidgets('Show album goes to the album of the library row', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'b');
    await pick(tester, 'Show album');

    expect(location(h), albumLocation(const AlbumKey('ann', 'al')));
  });

  testWidgets('Find lyrics online works for a track outside the library', (
    tester,
  ) async {
    await openWithTracks(tester, h, _library, location: '/home');
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, h, [
      Track(uri: p['a']!, title: 'a'),
      const Track(uri: '/elsewhere/x.mp3', title: 'Real title'),
    ]);
    await openQueueMenu(tester, 'Real title');
    await pick(tester, 'Find lyrics online…');

    // Nothing is sent before the notice is answered.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Search'),
      ),
    );
    await settleDb(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
  });

  testWidgets('Add to playlist adds the song', (tester) async {
    final p = await open(tester);
    final id = await seedPlaylist(tester, h, 'Mix', const []);
    await openQueueMenu(tester, 'b');
    await pick(tester, 'Add to playlist…');
    await tester.tap(inPicker('Mix'));
    await settleDb(tester);

    expect(await storedPaths(tester, h, id), [p['b']]);
  });

  testWidgets('a reorder while the menu is open still removes that song', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'b');
    await player().moveTrack(1, 2);
    await tester.pump();
    await pick(tester, 'Remove from queue');

    expect(queueTitles(h), ['a', 'c']);
  });

  testWidgets('a queue replaced while the menu is open is left alone', (
    tester,
  ) async {
    final p = await open(tester);
    await openQueueMenu(tester, 'a');
    await player().openTracks([
      Track(uri: p['c']!, title: 'c'),
      Track(uri: p['b']!, title: 'b'),
      Track(uri: p['a']!, title: 'a'),
      Track(uri: p['a']!, title: 'a2'),
    ]);
    await tester.pump();
    await pick(tester, 'Remove from queue');

    expect(queueTitles(h), ['c', 'b', 'a', 'a2']);
  });

  testWidgets('a queue cleared down to one song does not take its entry', (
    tester,
  ) async {
    // clearQueue keeps the playing song at entry 0, so entry 0 now names
    // another song than the row the menu was opened on.
    await open(tester);
    await player().jump(1);
    await tester.pumpAndSettle();
    await openQueueMenu(tester, 'a');
    await player().clearQueue();
    await tester.pump();
    await pick(tester, 'Remove from queue');

    expect(queueTitles(h), ['b']);
    expect(find.text('The queue changed, so nothing was done'), findsOneWidget);
  });

  testWidgets('a failed database read leaves the cut-down menu', (
    tester,
  ) async {
    await open(tester);
    gate.failNext('has_album');
    await openQueueMenu(tester, 'b');

    // Finding lyrics does not need the library row, so it stays.
    expect(menuLabels(tester, allMenuLabels), [
      'Play next',
      'Find lyrics online…',
      'Show in file manager',
      'Remove from queue',
    ]);
    expect(tester.takeException(), isNull);
  });
}
