import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/artists/artist_grid_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'A'),
  TestTrack('a2', artist: 'Ann', album: 'A'),
  TestTrack('b1', artist: 'Bob', album: 'B'),
];

void main() {
  Future<void> toGrid(WidgetTester tester) async {
    // The icon shows the current view; a tap switches to the other one.
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts as a list and the toggle switches to a grid', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    expect(find.byType(ArtistTile), findsNWidgets(2));
    expect(find.byType(ArtistGridTile), findsNothing);

    await toGrid(tester);

    expect(find.byType(ArtistGridTile), findsNWidgets(2));
    expect(find.byType(ArtistTile), findsNothing);
    expect(find.byTooltip('Grid'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('2 songs'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(2));

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistTile), findsNWidgets(2));
  });

  testWidgets('the grid view survives leaving and re-entering the tab', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await toGrid(tester);

    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    goTo(tester, h, '/artists');
    await tester.pumpAndSettle();

    expect(find.byType(ArtistGridTile), findsNWidgets(2));
  });

  testWidgets('tapping a tile opens the artist page', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await toGrid(tester);

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(location(h), artistLocation('bob'));
  });

  testWidgets('right click offers Play next for the artist', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await toGrid(tester);

    await tester.tap(find.text('Ann'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.tracks)
          t.title,
      ],
      ['a1', 'a2'],
    );
  });

  testWidgets('large text does not overflow the tiles', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await toGrid(tester);

    expect(find.byType(ArtistGridTile), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(480, 720);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
