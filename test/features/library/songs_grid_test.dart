import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/library_view_modes.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

import 'package:kanaru/shared/widgets/library_grid/song_grid_tile.dart';
import 'package:kanaru/shared/widgets/library_grid/library_grid_card.dart';

String _name(int i) => 's${i.toString().padLeft(4, '0')}';

void main() {
  /// Lets the page reads that a scroll started finish.
  Future<void> settleRows(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> toGrid(WidgetTester tester) async {
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    await settleRows(tester);
  }

  const tracks = [
    TestTrack('a', artist: 'Ann', album: 'Al'),
    TestTrack('b', artist: 'Bob', album: 'Al'),
    TestTrack('c', artist: 'Cy', album: 'Al'),
  ];

  testWidgets('the view button switches between list and grid', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, tracks, location: '/songs');
    expect(find.byType(SongTile), findsNWidgets(3));
    expect(find.byType(SongGridTile), findsNothing);

    await toGrid(tester);
    expect(find.byType(SongGridTile), findsNWidgets(3));
    expect(find.byType(SongTile), findsNothing);
    expect(find.text('Ann'), findsOneWidget);
    expect(h.container.read(libraryViewModesProvider).songs, AlbumsView.grid);

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(SongTile), findsNWidgets(3));
  });

  testWidgets('the grid view stays while the app runs', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, tracks, location: '/songs');
    await toGrid(tester);

    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();
    await settleRows(tester);

    expect(find.byType(SongGridTile), findsNWidgets(3));
  });

  testWidgets('tapping a tile plays the whole list from it', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, tracks, location: '/songs');
    await toGrid(tester);

    await tester.tap(find.text('b'));
    await settleRows(tester);

    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['a', 'b', 'c']);
    expect(queue.current?.title, 'b');
  });

  testWidgets(
    'a right click opens the song modal and the card has no More options button',
    (tester) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, tracks, location: '/songs');
      await toGrid(tester);

      expect(find.byTooltip('More options'), findsNothing);
      await tester.tap(find.text('a'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Go to album'), findsOneWidget);
      expect(find.text('Play next'), findsOneWidget);
    },
  );

  testWidgets('a large library reads only the tiles in view', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, [
      for (var i = 0; i < 5000; i++) TestTrack(_name(i)),
    ], location: '/songs');
    await toGrid(tester);
    expect(find.text(_name(0)), findsOneWidget);
    final tiles = find.byType(SongGridTile).evaluate().length;
    expect(tiles, lessThan(200), reason: 'only the visible rows are built');

    final scrollable = tester.state<ScrollableState>(
      find.ancestor(
        of: find.byType(SongGridTile).first,
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await settleRows(tester);

    expect(find.text(_name(4999)), findsOneWidget);
    expect(find.text(_name(0)), findsNothing);
    expect(find.byType(LibraryGridCardPlaceholder), findsNothing);
  });
}
