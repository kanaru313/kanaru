import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/genres/genre_header.dart';
import 'package:kanaru/features/library/play_shuffle_actions.dart';
import 'package:kanaru/features/library/widgets/cover_tint_page_background.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('a', genre: 'Rock', album: 'Al', albumArtist: 'X'),
  TestTrack('b', genre: 'Rock'),
];

final _location = genreLocation('rock');

void main() {
  testWidgets('a wide window puts the genre in a side pane beside the songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _location);

    final pane = find.byType(GenreSidePane);
    expect(pane, findsOneWidget);
    expect(find.byType(GenreHeader), findsNothing);
    expect(
      tester.getTopLeft(find.text('a')).dx,
      greaterThanOrEqualTo(tester.getTopRight(pane).dx),
    );

    final cover = find.descendant(
      of: pane,
      matching: find.byType(PlaylistCover),
    );
    expect(tester.getSize(cover), const Size(320, 320));
    expect(
      find.descendant(of: pane, matching: find.byType(ShaderMask)),
      findsWidgets,
    );
    expect(
      tester
          .getTopRight(
            find.descendant(
              of: pane,
              matching: find.byType(PlayShuffleActions),
            ),
          )
          .dx,
      moreOrLessEquals(tester.getTopRight(pane).dx - 16),
    );
    expect(find.byType(CoverTintPageBackground), findsOneWidget);
  });

  testWidgets('a narrow window keeps the header above the songs', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _location);
    tester.view.physicalSize = const Size(700, 800);
    await tester.pumpAndSettle();

    expect(find.byType(GenreSidePane), findsNothing);
    expect(find.byType(GenreHeader), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('a')).dy,
      greaterThan(tester.getBottomLeft(find.byType(GenreHeader)).dy),
    );
  });
}
