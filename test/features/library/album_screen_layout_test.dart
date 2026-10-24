import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/album_header.dart';
import 'package:kanaru/features/library/albums/album_side_pane.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _album = [
  TestTrack('One', artist: 'Ann', album: 'Al', track: 1, year: 2007),
  TestTrack('Two', artist: 'Ann', album: 'Al', track: 2, year: 2007),
];

final _location = albumLocation(const AlbumKey('ann', 'al'));

void main() {
  testWidgets('a wide window puts the album in a side pane beside the tracks', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);

    expect(find.byType(AlbumSidePane), findsOneWidget);
    expect(find.byType(AlbumHeader), findsNothing);
    expect(find.text('2007'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('One')).dx,
      greaterThanOrEqualTo(tester.getTopRight(find.byType(AlbumSidePane)).dx),
    );
  });

  testWidgets('a narrow window keeps the header above the tracks', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    tester.view.physicalSize = const Size(700, 800);
    await tester.pumpAndSettle();

    expect(find.byType(AlbumSidePane), findsNothing);
    expect(find.byType(AlbumHeader), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('One')).dy,
      greaterThan(tester.getBottomLeft(find.byType(AlbumHeader)).dy),
    );
  });

  testWidgets('the bar over the tracks shows the count and opens the filter '
      'under it, as wide as the list; its close button hides it', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    expect(find.text('2 songs · 0:02'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
    final box = find.byType(InPageSearchBox);
    expect(box, findsOneWidget);
    expect(tester.getSize(box).width, greaterThan(inPageSearchWidth));
    expect(
      tester.getTopLeft(box).dy,
      greaterThan(tester.getBottomLeft(find.text('2 songs · 0:02')).dy),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsNothing);
  });
}
