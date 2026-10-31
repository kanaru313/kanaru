import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_entries_view.dart';
import 'package:kanaru/features/playlists/playlist_entry_placeholder.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import '../library/browse_test_data.dart' show goTo;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// Titles `S000` .. `S249`: a playlist of three pages.
final bigTitles = [for (var i = 0; i < 250; i++) 'S${'$i'.padLeft(3, '0')}'];

/// The scroll position of the song list. A wide page has a second scroll
/// view in its side pane, so the lookup starts at the list's own.
ScrollPosition pagePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.descendant(
          of: find.byType(PlaylistEntriesView),
          matching: find.byType(CustomScrollView),
        ),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Scrolls so that row [row] has its top [at] px below the top of the
/// window, then lets the rows in view be read.
Future<void> scrollToRow(
  WidgetTester tester,
  int row, {
  double at = 300,
}) async {
  final position = pagePosition(tester);
  final first = tester
      .widgetList<PlaylistEntryTile>(find.byType(PlaylistEntryTile))
      .first;
  final top = tester.getTopLeft(find.byWidget(first)).dy;
  final listTop = top - first.index * rowExtent(tester) + position.pixels;
  position.jumpTo(listTop + row * rowExtent(tester) - at);
  await tester.pump();
  await settleDb(tester);
}

/// Opens the app on a playlist "Big" holding [bigTitles].
Future<int> openBig(WidgetTester tester, LibraryHarness h) async {
  await openApp(tester, h, bigTitles);
  final id = await seedPlaylist(tester, h, 'Big', bigTitles);
  goTo(tester, h, '/playlists/$id');
  await settleDb(tester);
  return id;
}

/// Expects [titles] to be a run of consecutive entries of [bigTitles].
void expectConsecutive(List<String> titles) {
  expect(titles, isNotEmpty);
  final first = bigTitles.indexOf(titles.first);
  expect(first, isNot(-1));
  expect(titles, bigTitles.sublist(first, first + titles.length));
}

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  testWidgets('a playlist of three pages scrolls to its last row', (
    tester,
  ) async {
    await openBig(tester, h);
    expect(playlistSongCount('250 songs'), findsOneWidget);
    expect(shownTitles(tester).first, 'S000');

    final position = pagePosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await settleDb(tester);

    final titles = shownTitles(tester);
    expect(titles.last, 'S249');
    expectConsecutive(titles);
    expect(find.byType(PlaylistEntryPlaceholder), findsNothing);
  });

  testWidgets('a row far down is a slot until its page is read', (
    tester,
  ) async {
    await openBig(tester, h);
    final position = pagePosition(tester);

    position.jumpTo(150 * rowExtent(tester));
    await tester.pump();
    expect(find.byType(PlaylistEntryPlaceholder), findsWidgets);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);

    await settleDb(tester);
    expect(find.byType(PlaylistEntryPlaceholder), findsNothing);
    expectConsecutive(shownTitles(tester));
  });

  testWidgets('a drop across a page boundary is saved in order', (
    tester,
  ) async {
    final id = await openBig(tester, h);
    await scrollToRow(tester, 101, at: 420);
    final paths = await trackPaths(tester, h);

    // Row 101 (page 1) goes up to index 97 (page 0).
    final handle = find.descendant(
      of: find.widgetWithText(PlaylistEntryTile, 'S101'),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    final steps = (4 * rowExtent(tester) / 8).ceil();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(const Offset(0, -8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await settleDb(tester);

    final expected = [...bigTitles];
    expected.insert(97, expected.removeAt(101));
    final stored = await storedPaths(tester, h, id);
    expect(stored.sublist(95, 104), [
      for (final t in expected.sublist(95, 104)) paths[t],
    ]);
    final titles = shownTitles(tester);
    final at = titles.indexOf('S101');
    expect(titles.sublist(at - 1, at + 3), ['S096', 'S101', 'S097', 'S098']);
  });

  testWidgets('removing a row of the second page shifts the rest up', (
    tester,
  ) async {
    final id = await openBig(tester, h);
    await scrollToRow(tester, 150);

    final row = find.widgetWithText(PlaylistEntryTile, 'S150');
    await hoverOn(tester, row);
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.byTooltip('Remove from playlist'),
      ),
    );
    await settleDb(tester);

    final titles = shownTitles(tester);
    expect(titles, isNot(contains('S150')));
    final at = titles.indexOf('S149');
    expect(titles.sublist(at, at + 3), ['S149', 'S151', 'S152']);
    expect(await storedPaths(tester, h, id), hasLength(249));
    pagePosition(tester).jumpTo(0);
    await tester.pump();
    expect(playlistSongCount('249 songs'), findsOneWidget);
  });

  testWidgets('playing from the third page queues the whole playlist', (
    tester,
  ) async {
    await openBig(tester, h);
    await scrollToRow(tester, 210);

    await tester.tap(find.text('S210'));
    await settleDb(tester);

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], bigTitles);
    expect(queue.index, 210);
    expect(h.backend.calls.last, startsWith('open(S210'));
  });

  testWidgets('a tap during a move plays the order the database ends up with', (
    tester,
  ) async {
    await openMix(tester, h);

    await dragFirstRowDown(tester);
    // The drop settles, then the move is saved: Alpha is at index 2 and
    // Bravo is the first row on screen.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bravo'));
    await settleDb(tester);

    final queue = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in queue.original) t.title],
      ['Bravo', 'Charlie', 'Alpha', 'Delta'],
    );
    expect(queue.index, 0);
  });

  testWidgets('the header queue menu adds the playlist in database order', (
    tester,
  ) async {
    await openMix(tester, h);

    await dragFirstRowDown(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await settleDb(tester);

    final queue = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in queue.original) t.title],
      ['Bravo', 'Charlie', 'Alpha', 'Delta'],
    );
  });

  testWidgets('leaving the page while the queue is read plays nothing', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    h = LibraryHarness(refreshInterval: Duration.zero, interceptor: gate);
    await openMix(tester, h);

    // The queue read is the one that selects the playable tracks of a
    // playlist whole; hold it until the page is gone.
    final release = gate.holdNext(
      'WHERE e.playlist_id = ?1\nORDER BY e.position, e.id',
    );
    await tester.tap(find.text('Charlie'));
    await tester.pump();
    goTo(tester, h, '/playlists');
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistEntriesView), findsNothing);

    release();
    await settleDb(tester);

    expect(tester.takeException(), isNull);
    expect(h.container.read(playerServiceProvider).queue.original, isEmpty);
    expect(h.backend.calls.where((c) => c.startsWith('open')), isEmpty);
  });

  testWidgets('positions with a gap show a slot and do not crash', (
    tester,
  ) async {
    await openApp(tester, h, mixTitles);
    final id = await seedPlaylist(tester, h, 'Mix', mixTitles);
    await tester.runAsync(
      () => h.db.customStatement(
        'UPDATE playlist_entries SET position = position + 10 '
        'WHERE playlist_id = $id AND position = 3',
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(tester.takeException(), isNull);
    expect(playlistSongCount('4 songs'), findsOneWidget);
    expect(shownTitles(tester), ['Alpha', 'Bravo', 'Charlie']);
    expect(find.byType(PlaylistEntryPlaceholder), findsOneWidget);
  });

  testWidgets('positions that repeat do not crash', (tester) async {
    await openApp(tester, h, mixTitles);
    final id = await seedPlaylist(tester, h, 'Mix', mixTitles);
    await tester.runAsync(
      () => h.db.customStatement(
        'UPDATE playlist_entries SET position = 1 '
        'WHERE playlist_id = $id AND position = 2',
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(tester.takeException(), isNull);
    expect(playlistSongCount('4 songs'), findsOneWidget);
    // Index 1 holds the later of the two, index 2 is a gap.
    expect(shownTitles(tester), ['Alpha', 'Charlie', 'Delta']);
    expect(find.byType(PlaylistEntryPlaceholder), findsOneWidget);
  });
}
