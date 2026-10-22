import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show goTo, location;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

const _titles = ['Alpha', 'Bravo', 'Charlie', 'Delta'];

/// Titles of the rows on screen, top to bottom.
List<String> shown(WidgetTester tester) {
  final byY = {
    for (final tile in tester.widgetList<PlaylistEntryTile>(
      find.byType(PlaylistEntryTile),
    ))
      tester.getTopLeft(find.byWidget(tile)).dy:
          tile.entry.track?.title ?? tile.entry.path,
  };
  return [for (final y in byY.keys.toList()..sort()) byY[y]!];
}

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<int> openMix(WidgetTester tester) async {
    await openApp(tester, h, _titles);
    final id = await seedPlaylist(tester, h, 'Mix', _titles);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    return id;
  }

  testWidgets('shows the name, count and entries in order', (tester) async {
    await openMix(tester);

    expect(find.text('4 songs'), findsOneWidget);
    expect(shown(tester), _titles);
  });

  testWidgets('a drag is saved, never flickers back and survives a reload', (
    tester,
  ) async {
    final id = await openMix(tester);
    final paths = await trackPaths(tester, h);
    final handle = find.byIcon(Icons.drag_handle_rounded).first;

    // Drop the first row just below the third.
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 18; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();

    // Every frame until the write and the reload are done.
    const moved = ['Bravo', 'Charlie', 'Alpha', 'Delta'];
    final frames = <List<String>>[];
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(shown(tester));
    }
    await settleDb(tester);

    expect(shown(tester), moved);
    final first = frames.indexWhere((f) => f.join() == moved.join());
    expect(first, isNot(-1), reason: 'the new order appeared');
    expect(
      frames.skip(first).every((f) => f.join() == moved.join()),
      isTrue,
      reason: 'the old order came back for a frame: $frames',
    );
    expect(await storedPaths(tester, h, id), [for (final t in moved) paths[t]]);

    h.container.invalidate(playlistPageProvider(id));
    await settleDb(tester);
    expect(shown(tester), moved);
  });

  testWidgets('removing a row keeps the positions dense', (tester) async {
    final id = await openMix(tester);

    await tester.tap(find.byTooltip('Remove from playlist').at(1));
    await settleDb(tester);

    expect(shown(tester), ['Alpha', 'Charlie', 'Delta']);
    final stored = await tester.runAsync(
      () => h.db.select(h.db.playlistEntries).get(),
    );
    expect(stored!.map((e) => e.position).toList()..sort(), [0, 1, 2]);
    expect(stored.every((e) => e.playlistId == id), isTrue);
    expect(find.text('3 songs'), findsOneWidget);
  });

  testWidgets('rename from the menu', (tester) async {
    final id = await openMix(tester);

    await tester.tap(find.byTooltip('Playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, 'Mix');
    await tester.enterText(field, 'Road trip');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await settleDb(tester);

    // The page header and the sidebar row.
    expect(find.text('Road trip'), findsNWidgets(2));
    final summary = await tester.runAsync(() => h.db.playlistSummary(id));
    expect(summary!.name, 'Road trip');
  });

  testWidgets('delete leaves the page first and never shows "not found"', (
    tester,
  ) async {
    final id = await openMix(tester);

    await tester.tap(find.byTooltip('Playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Mix”?'), findsOneWidget);
    expect(find.textContaining('It has 4 songs.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    final sawNotFound = <bool>[];
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      sawNotFound.add(find.text('Playlist not found').evaluate().isNotEmpty);
    }
    await settleDb(tester);

    expect(sawNotFound, everyElement(isFalse));
    expect(location(h), '/playlists');
    expect(await tester.runAsync(() => h.db.playlistSummary(id)), isNull);
    expect(find.text('Mix'), findsNothing, reason: 'gone from the sidebar');
  });

  testWidgets('cancelling the delete confirmation keeps the playlist', (
    tester,
  ) async {
    final id = await openMix(tester);

    await tester.tap(find.byTooltip('Playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await settleDb(tester);

    expect(location(h), '/playlists/$id');
    expect(await tester.runAsync(() => h.db.playlistSummary(id)), isNotNull);
  });

  testWidgets('an entry without a track says so and is skipped on play', (
    tester,
  ) async {
    await openApp(tester, h, _titles);
    final paths = await trackPaths(tester, h);
    final id = await tester.runAsync(
      () => h.db.createPlaylist(
        'Mix',
        now: 1,
        paths: [paths['Alpha']!, '/gone/lost.mp3', paths['Charlie']!],
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(find.text('Not in library'), findsOneWidget);

    await tester.tap(find.text('Charlie'));
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['Alpha', 'Charlie']);
    expect(queue.index, 1);
    expect(h.backend.calls.last, startsWith('open(Charlie'));
  });

  testWidgets('Play starts from the first song that can play', (tester) async {
    await openApp(tester, h, _titles);
    final paths = await trackPaths(tester, h);
    final id = await tester.runAsync(
      () => h.db.createPlaylist(
        'Mix',
        now: 1,
        paths: ['/gone/lost.mp3', paths['Bravo']!, paths['Delta']!],
      ),
    );
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['Bravo', 'Delta']);
    expect(queue.index, 0);
  });

  testWidgets('an empty playlist explains how to fill it', (tester) async {
    await openApp(tester, h, _titles);
    final id = await seedPlaylist(tester, h, 'Empty', const []);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);

    expect(find.text('This playlist is empty'), findsOneWidget);
  });
}
