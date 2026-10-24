import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

/// Enough tracks, albums and artists to scroll every page.
final _tracks = [
  for (var i = 0; i < 40; i++)
    TestTrack(
      't${i.toString().padLeft(2, '0')}',
      artist: i.isEven ? 'Ann' : 'Artist $i',
      album: 'Album $i',
    ),
];

void main() {
  /// Scrolls the page's scroll view so its first [tile] is cut off by the
  /// top edge, hovers the visible part, and checks where the hover ink goes.
  ///
  /// Ink is painted (and clipped) by the nearest [Material]. The test fails
  /// when that Material reaches above the scroll view, which lets the ink
  /// spill over the page title.
  ///
  /// [inkHost] finds the element whose nearest [Material] paints the ink
  /// (the tile itself by default). A host given here is a Material of the
  /// row, which must sit inside the scroll view to be clipped by it.
  Future<void> expectInkClipped(
    WidgetTester tester,
    Finder tile, {
    Finder? inkHost,
  }) async {
    final scrollable = find
        .ancestor(of: tile.first, matching: find.byType(Scrollable))
        .first;
    await tester.drag(scrollable, const Offset(0, -100));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(scrollable);
    final first = tester.getRect(tile.first);
    expect(first.top, lessThan(viewport.top), reason: 'the tile is cut off');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(first.center.dx, viewport.top + 4));
    await tester.pumpAndSettle();

    final host = inkHost ?? tile;
    final ink = Material.of(tester.element(host.first)) as RenderBox;
    if (inkHost != null) {
      // The row paints its own ink, cut off by the scroll view like the row.
      RenderObject? parent = ink.parent;
      final scrollBox = tester.renderObject(scrollable);
      while (parent != null && parent != scrollBox) {
        parent = parent.parent;
      }
      expect(
        parent,
        isNotNull,
        reason: 'the ink host is inside the scroll view',
      );
      return;
    }
    final inkArea = ink.localToGlobal(Offset.zero) & ink.size;
    expect(
      inkArea.top,
      greaterThanOrEqualTo(viewport.top),
      reason: 'ink must not reach above the scroll view',
    );
  }

  testWidgets('album grid hover stays inside the grid', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    await expectInkClipped(tester, find.byType(AlbumGridTile));
  });

  testWidgets('artist list hover stays inside the list', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/artists');
    await expectInkClipped(tester, find.byType(ArtistTile));
  });

  testWidgets('song list hover stays inside the list', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/songs');
    final tile = find.byType(SongTile);
    // A song row has its own Material, so the ink host is found from its
    // InkWell: a lookup from the row would skip it and measure the page.
    final inkWell = find.descendant(
      of: tile.first,
      matching: find.byType(InkWell),
    );
    await expectInkClipped(tester, tile, inkHost: inkWell);
  });

  testWidgets('artist page album grid hover stays inside the page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));
    final grid = find.byType(AlbumGridTile);
    final ink = Material.of(tester.element(grid.first)) as RenderBox;
    final page = tester.getRect(find.byType(CustomScrollView));
    expect(
      ink.localToGlobal(Offset.zero).dy,
      greaterThanOrEqualTo(page.top),
      reason: 'the page scrolls as a whole, under the top bar',
    );
  });
}
