import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';
import 'queue_tile_menu_test_support.dart';

const _library = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
  TestTrack('c', artist: 'Ann', album: 'Al'),
];

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

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

  final modal = find.byType(SongModalHeader);

  testWidgets('a long press on the row opens the modal', (tester) async {
    await open(tester);
    await tester.longPress(queueRow('b').last);
    await settleSongModal(tester);

    expect(modal, findsOneWidget);
  });

  testWidgets('the menu key on a focused row opens the modal', (tester) async {
    await open(tester);
    Focus.of(tester.element(find.text('b').last)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleSongModal(tester);

    expect(modal, findsOneWidget);
  });

  testWidgets('a long press on the drag handle does not open the modal', (
    tester,
  ) async {
    await open(tester);
    await tester.longPress(find.byTooltip('Drag to reorder').last);
    await settleSongModal(tester);

    expect(modal, findsNothing);
    expect(queueTitles(h), ['a', 'b', 'c']);
  });

  testWidgets('Remove from queue is the first row, in the error color', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'b');

    final remove = modalAction('queue-remove');
    expect(remove, findsOneWidget);
    final error = Theme.of(tester.element(remove)).colorScheme.error;
    final icon = tester.widget<Icon>(
      find.descendant(
        of: remove,
        matching: find.byIcon(AppIcons.playlistRemove),
      ),
    );
    expect(icon.color, error);
    expect(
      tester.getTopLeft(remove).dy,
      lessThan(tester.getTopLeft(find.text('Go to album')).dy),
    );
  });

  testWidgets('Remove takes out the row it was opened on of a duplicate', (
    tester,
  ) async {
    await open(tester, const ['a', 'b', 'a']);
    await openQueueMenu(tester, 'b');
    await tapModalAction(tester, 'Remove from queue');
    expect(queueTitles(h), ['a', 'a']);

    // The second copy of the file is still queued, only the row opened goes.
    await tester.longPress(queueRow('a').last);
    await settleSongModal(tester);
    await tapModalAction(tester, 'Remove from queue');
    expect(queueTitles(h), ['a']);
  });

  testWidgets('Remove after the row left the queue says so', (tester) async {
    await open(tester);
    await openQueueMenu(tester, 'c');
    await player().removeTrack(2);
    await tester.pump();
    await tapModalAction(tester, 'Remove from queue');

    expect(queueTitles(h), ['a', 'b']);
    expect(find.text('The queue changed, so nothing was done'), findsOneWidget);
  });

  testWidgets('Play next in the footer moves the row, never copies it', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'c');
    await tapModalAction(tester, 'Play next');

    expect(queueTitles(h), ['a', 'c', 'b']);
    expect(
      h.container.read(playerServiceProvider).queue.original,
      hasLength(3),
    );
  });

  testWidgets('Play next on the playing row or a play next row says so', (
    tester,
  ) async {
    await open(tester);
    await openQueueMenu(tester, 'a');
    await tapModalAction(tester, 'Play next');
    expect(find.text('Already playing or up next'), findsOneWidget);
    expect(queueTitles(h), ['a', 'b', 'c']);

    await player().moveToPlayNext(2);
    await tester.pumpAndSettle();
    await openQueueMenu(tester, 'c');
    await tapModalAction(tester, 'Play next');
    expect(find.text('Already playing or up next'), findsOneWidget);
    expect(queueTitles(h), ['a', 'c', 'b']);
  });

  testWidgets('Play next after the queue was replaced is left alone', (
    tester,
  ) async {
    final p = await open(tester);
    await openQueueMenu(tester, 'c');
    await player().openTracks([
      Track(uri: p['c']!, title: 'c'),
      Track(uri: p['b']!, title: 'b'),
      Track(uri: p['a']!, title: 'a'),
    ]);
    await tester.pump();
    await tapModalAction(tester, 'Play next');

    expect(queueTitles(h), ['c', 'b', 'a']);
    expect(find.text('The queue changed, so nothing was done'), findsOneWidget);
  });

  testWidgets('Add to queue appends one copy of the song', (tester) async {
    await open(tester);
    await openQueueMenu(tester, 'b');
    await tapModalAction(tester, 'Add to queue');

    expect(queueTitles(h), ['a', 'b', 'c', 'b']);
  });

  testWidgets('Esc closes only the modal, not the queue sheet', (tester) async {
    await open(tester);
    await openQueueMenu(tester, 'b');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleSongModal(tester);

    expect(modal, findsNothing);
    expect(queueRow('b'), findsWidgets);
  });
}
