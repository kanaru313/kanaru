import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/genres/genre_header.dart';
import 'package:kanaru/features/library/genres/genre_hero_cover.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/features/library/play_shuffle_actions.dart';
import 'package:kanaru/features/library/widgets/cover_tint_page_background.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/card_shelf.dart';
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
    await openWithTracks(tester, h, const [
      TestTrack(
        'a',
        genre: 'Rock',
        album: 'Al',
        albumArtist: 'X',
        coverKey: 'c1',
      ),
      TestTrack('b', genre: 'Rock', coverKey: 'c2'),
    ], location: _location);

    final pane = find.byType(GenreSidePane);
    expect(pane, findsOneWidget);
    expect(find.byType(GenreHeader), findsNothing);
    expect(
      tester.getTopLeft(find.text('a')).dx,
      greaterThanOrEqualTo(tester.getTopRight(pane).dx),
    );

    final backdrop = find.byType(GenreHeroBackdrop);
    final card = find.byType(GenreHeroCard);
    expect(find.descendant(of: pane, matching: backdrop), findsOneWidget);
    expect(find.descendant(of: pane, matching: card), findsOneWidget);
    expect(tester.getSize(backdrop), const Size(320, 320));
    expect(tester.getSize(card), const Size(240, 240));
    expect(tester.getCenter(card), tester.getCenter(backdrop));

    // The backdrop sits under the fade masks, the card does not.
    final masks = find.descendant(of: pane, matching: find.byType(ShaderMask));
    expect(
      find.descendant(of: masks.first, matching: backdrop),
      findsOneWidget,
    );
    expect(find.descendant(of: masks.first, matching: card), findsNothing);
    expect(find.descendant(of: masks.last, matching: card), findsNothing);

    final washout = find.descendant(
      of: backdrop,
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(washout).opacity, 0.35);
    expect(
      find.descendant(of: pane, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    expect(
      find.descendant(of: pane, matching: find.byType(ImageFiltered)),
      findsNothing,
    );

    // The backdrop collage is built at the card's size and stretched.
    final backdropCover = find.descendant(
      of: backdrop,
      matching: find.byType(PlaylistCover),
    );
    expect(tester.widget<PlaylistCover>(backdropCover).size, 232);
    expect(tester.getSize(backdropCover), const Size(232, 232));
    expect(
      tester
          .getRect(
            find.descendant(of: backdrop, matching: find.byType(FittedBox)),
          )
          .size,
      const Size(320, 320),
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
    expect(
      tester
          .widget<CoverTintPageBackground>(find.byType(CoverTintPageBackground))
          .coverKeys,
      unorderedEquals(['c1', 'c2']),
    );
  });

  testWidgets('without covers only the card shows the placeholder icon', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _location);

    final icons = find.descendant(
      of: find.byType(GenreSidePane),
      matching: find.byIcon(AppIcons.genre),
    );
    expect(icons, findsNWidgets(2));
    expect(icons.hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GenreHeroCard),
        matching: find.byIcon(AppIcons.genre),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the card and the backdrop share each cover image', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('genre_hero');
    addTearDown(() => dir.deleteSync(recursive: true));
    String key(String shard) => '$shard/$shard${'0' * 62}.jpg';
    final h = LibraryHarness(coverCacheDirectory: dir.path);
    await openWithTracks(tester, h, [
      for (final (i, shard) in ['aa', 'bb', 'cc', 'dd'].indexed)
        TestTrack('t$i', genre: 'Rock', album: 'Al$i', coverKey: key(shard)),
    ], location: _location);

    final images = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byType(GenreSidePane),
            matching: find.byType(Image),
          ),
        )
        .toList();
    expect(images, hasLength(8));
    expect(images.map((i) => i.image).toSet(), hasLength(4));
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
    final actions = find.byType(PlayShuffleActions);
    expect(
      tester.getTopLeft(actions).dx,
      moreOrLessEquals(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(GenreHeader),
                matching: find.text('Rock'),
              ),
            )
            .dx,
      ),
    );
    expect(
      find.descendant(of: actions, matching: find.text('Shuffle')),
      findsOneWidget,
    );
  });

  testWidgets('the albums sit on one sideways line', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('a', genre: 'Rock', album: 'Al', albumArtist: 'X'),
      TestTrack('b', genre: 'Rock', album: 'Bo', albumArtist: 'X'),
    ], location: _location);

    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(CardShelf),
      ),
      findsOneWidget,
    );
    final tiles = find.byType(AlbumGridTile);
    expect(tiles, findsNWidgets(2));
    expect(
      tester.getTopLeft(tiles.at(0)).dy,
      tester.getTopLeft(tiles.at(1)).dy,
    );
  });
}
