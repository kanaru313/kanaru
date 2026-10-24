import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/genres/genre_avatar.dart';
import 'package:kanaru/features/library/genres/genre_grid_tile.dart';
import 'package:kanaru/features/library/genres/genre_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('r1', genre: 'Rock', album: 'A'),
  TestTrack('r2', genre: 'rock', album: 'A'),
  TestTrack('rp', genre: 'Rock; Pop'),
  TestTrack('j1', genre: 'Jazz'),
  TestTrack('none'),
];

void main() {
  Future<void> toGrid(WidgetTester tester) async {
    // The icon shows the current view; a tap switches to the other one.
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every genre with its song count, round and sorted', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/genres');
    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    // Three genres, then the song with no genre tag.
    expect(find.byType(GenreTile), findsNWidgets(4));
    expect(find.text('Rock'), findsOneWidget, reason: 'spellings merge');
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('1 song'), findsNWidgets(3));
    expect(top('Jazz'), lessThan(top('Pop')));
    expect(top('Pop'), lessThan(top('Rock')));
    expect(top('Rock'), lessThan(top('Unknown genre')));
    expect(find.byType(GenreAvatar), findsNWidgets(4));
    expect(find.byType(CircleAvatar), findsNWidgets(4));
    expect(find.byType(AlbumArtwork), findsNothing);
  });

  testWidgets('the toggle switches to round grid tiles and back', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await toGrid(tester);

    expect(find.byType(GenreGridTile), findsNWidgets(4));
    expect(find.byType(GenreTile), findsNothing);
    expect(find.byTooltip('Grid'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(4));
    expect(find.byType(AlbumArtwork), findsNothing);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(GenreTile), findsNWidgets(4));
  });

  testWidgets('the grid view survives leaving and re-entering the tab', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/genres');
    await toGrid(tester);

    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    goTo(tester, h, '/genres');
    await tester.pumpAndSettle();

    expect(find.byType(GenreGridTile), findsNWidgets(4));
  });

  testWidgets('tapping a genre opens its page, in the list and the grid', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();
    expect(location(h), genreLocation('jazz'));

    goTo(tester, h, '/genres');
    await tester.pumpAndSettle();
    await toGrid(tester);
    await tester.tap(find.text('Pop'));
    await tester.pumpAndSettle();
    expect(location(h), genreLocation('pop'));
  });

  testWidgets('right click offers Play next for all songs of the genre', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/genres');

    await tester.tap(find.text('Rock'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.tracks)
          t.title,
      ],
      ['r1', 'r2', 'rp'],
    );
  });

  testWidgets('large text does not overflow the grid', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/genres');
    await toGrid(tester);

    expect(find.byType(GenreGridTile), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(480, 720);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('without songs the page says so', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, const [], location: '/genres');

    expect(find.text('No genres yet'), findsOneWidget);
    expect(find.byTooltip('List'), findsOneWidget);
  });

  testWidgets('without a music folder it points to Songs', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester);
    goTo(tester, h, '/genres');
    await tester.pumpAndSettle();

    expect(find.text('Add a music folder in Songs.'), findsOneWidget);
    expect(find.byTooltip('List'), findsNothing);
  });
}
