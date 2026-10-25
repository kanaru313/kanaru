import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/album_header.dart';
import 'package:kanaru/features/library/albums/album_side_pane.dart';
import 'package:kanaru/features/library/play_shuffle_actions.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/expanding_search_bar.dart';
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

    final actions = find.descendant(
      of: find.byType(AlbumSidePane),
      matching: find.byType(PlayShuffleActions),
    );
    expect(
      tester.getTopRight(actions).dx,
      moreOrLessEquals(tester.getTopRight(find.byType(AlbumSidePane)).dx - 16),
    );
    expect(
      tester.getTopLeft(actions).dx,
      greaterThan(tester.getTopLeft(find.text('Al')).dx),
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
    expect(
      tester.getTopLeft(find.byType(PlayShuffleActions)).dx,
      moreOrLessEquals(tester.getTopLeft(find.text('Al')).dx),
    );
  });

  testWidgets('the filter grows out of its button over the whole bar, from '
      'the note icon to the button, which turns into a close button', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _album, location: _location);
    expect(find.text('2 songs · 0:02'), findsOneWidget);
    final note = tester.getTopLeft(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('2 songs · 0:02'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byIcon(AppIcons.musicNoteOutlined),
      ),
    );

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pump();
    await tester.pump(expandingSearchDuration ~/ 2);
    final box = find.byType(InPageSearchBox);
    final shown = find.ancestor(of: box, matching: find.byType(SizeTransition));
    final half = tester.getTopLeft(shown).dx;
    expect(half, greaterThan(note.dx));

    await tester.pumpAndSettle();
    expect(tester.getSize(box).width, greaterThan(inPageSearchWidth));
    expect(tester.getTopLeft(box).dx, moreOrLessEquals(note.dx));
    expect(tester.getTopLeft(shown).dx, lessThan(half));
    final close = find.byTooltip('Close');
    expect(
      tester.getTopRight(box).dx,
      lessThanOrEqualTo(tester.getTopLeft(close).dx),
    );
    expect(
      find.descendant(of: box, matching: find.byIcon(AppIcons.search)),
      findsOneWidget,
    );
    expect(find.byTooltip('Filter in this page'), findsNothing);

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsNothing);
    expect(find.byTooltip('Filter in this page'), findsOneWidget);
  });
}
