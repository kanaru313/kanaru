import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/artists/artist_page_data.dart';
import 'package:kanaru/features/library/artists/artist_page_sections.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:kanaru/shared/widgets/page_scaffold.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

import 'package:kanaru/shared/widgets/library_grid/album_grid_tile.dart';

const _ann = [
  TestTrack(
    'a1',
    artist: 'Ann',
    album: 'Alpha',
    albumArtist: 'Ann',
    year: 2010,
  ),
  TestTrack(
    'a2',
    artist: 'Ann',
    album: 'Alpha',
    albumArtist: 'Ann',
    year: 2010,
  ),
  TestTrack('z1', artist: 'Ann', album: 'Zeta', albumArtist: 'Ann', year: 1990),
  TestTrack('t1', artist: 'X; Ann', album: 'Theirs', albumArtist: 'Bob'),
  TestTrack('o1', artist: 'X; Ann', album: 'Other', albumArtist: 'Cy'),
];

const _sortable = [
  TestTrack(
    'a1',
    artist: 'Ann',
    album: 'Big Alpha',
    albumArtist: 'Ann',
    year: 2010,
  ),
  TestTrack('l1', artist: 'Ann', album: 'Alto', albumArtist: 'Ann', year: 1999),
  TestTrack('z1', artist: 'Ann', album: 'Zeta', albumArtist: 'Ann', year: 2005),
];

const _rock = [
  TestTrack('r1', genre: 'Rock', album: 'Loud', albumArtist: 'X'),
  TestTrack('r2', genre: 'Rock', album: 'Loud', albumArtist: 'X'),
  TestTrack('r3', genre: 'Rock', album: 'Quiet', albumArtist: 'Y'),
  TestTrack('u1', album: 'Plain', albumArtist: 'X'),
];

final _annAlbums = artistAlbumsLocation('ann');
final _annAppearsOn = artistAppearsOnLocation('ann');
final _rockAlbums = genreAlbumsLocation('rock');

/// Titles of the albums on the page, top to bottom, whichever view it is in.
List<String> _titles(WidgetTester tester) => [
  for (final w in tester.widgetList<AlbumGridTile>(find.byType(AlbumGridTile)))
    w.data.title,
  for (final w in tester.widgetList<AlbumListTile>(find.byType(AlbumListTile)))
    w.album.title,
];

/// The "N songs" line of a list row.
final _songTotals = find.textContaining(RegExp(r'\d songs?'));

final _filterField = find.descendant(
  of: find.byType(InPageSearchBox),
  matching: find.byType(TextField),
);

Future<void> _filterBy(WidgetTester tester, String text) async {
  if (find.byType(InPageSearchBox).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(_filterField, text);
  await tester.pump(const Duration(milliseconds: 150));
}

int _shellIndex(WidgetTester tester) => tester
    .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
    .currentIndex;

Future<void> _toList(WidgetTester tester, LibraryHarness h) async {
  await tester.tap(find.byTooltip('Grid'));
  await tester.pumpAndSettle();
  expect(h.container.read(settingsProvider).albumsView, AlbumsView.list);
}

void main() {
  testWidgets('the artist Albums list: title, count, year order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);

    expect(
      find.descendant(
        of: find.byType(PageScaffold),
        matching: find.text('Albums'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ann · 2 albums'), findsOneWidget);
    // Year ascending, which is not the title order.
    expect(_titles(tester), ['Zeta', 'Alpha']);
  });

  testWidgets('Appears on lists only the albums of others', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAppearsOn);

    expect(find.text('Appears on'), findsOneWidget);
    expect(find.text('Ann · 2 albums'), findsOneWidget);
    expect(_titles(tester), unorderedEquals(['Theirs', 'Other']));
  });

  testWidgets('the genre list names the genre; Unknown genre is translated', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _rock, location: _rockAlbums);
    expect(find.text('Rock · 2 albums'), findsOneWidget);
    expect(_titles(tester), ['Loud', 'Quiet']);

    goTo(tester, h, genreAlbumsLocation(unknownGenreKey));
    await tester.pumpAndSettle();
    expect(find.text('Unknown genre · 1 album'), findsOneWidget);
    expect(_titles(tester), ['Plain']);
  });

  testWidgets('filters by a title word and by an album artist word', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    await _filterBy(tester, 'alp');
    expect(_titles(tester), ['Alpha']);
    expect(find.text('Ann · 1 / 2 albums'), findsOneWidget);

    goTo(tester, h, _annAppearsOn);
    await tester.pumpAndSettle();
    await _filterBy(tester, 'bob');
    expect(_titles(tester), ['Theirs']);
    expect(find.text('Ann · 1 / 2 albums'), findsOneWidget);
  });

  testWidgets('"various" finds a merged album, not its hidden artist', (
    tester,
  ) async {
    const mix = AlbumKey('', 'mix');
    final h = LibraryHarness(
      overrides: [
        artistPageProvider.overrideWith(
          (ref, _) => Stream.value(
            const ArtistPageSections(
              name: 'Ann',
              songs: [],
              appearsOn: [],
              albums: [
                AlbumSummary(
                  key: mix,
                  title: 'Mix',
                  artist: 'Zed',
                  trackCount: 2,
                  addedAt: 1,
                  variousArtists: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: _annAlbums);

    await _filterBy(tester, 'various');
    expect(_titles(tester), ['Mix']);
    await _filterBy(tester, 'zed');
    expect(find.text('No albums match “zed”'), findsOneWidget);
  });

  testWidgets('a filter without a match says so', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    await _filterBy(tester, 'zzz');

    expect(find.text('No albums match “zzz”'), findsOneWidget);
    expect(_titles(tester), isEmpty);
    expect(find.text('Ann · 0 / 2 albums'), findsOneWidget);
  });

  testWidgets('matches keep the chosen sort, in both directions', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _sortable, location: _annAlbums);
    final saved = h.container.read(settingsProvider).albumSort;
    expect(_titles(tester), ['Alto', 'Zeta', 'Big Alpha']);

    await tester.tap(find.byTooltip('Order: Ascending'));
    await tester.pumpAndSettle();
    expect(_titles(tester), ['Big Alpha', 'Zeta', 'Alto']);
    await _filterBy(tester, 'al');

    // "Alto" starts with the word, so it ranks first by relevance alone;
    // the year order puts it last.
    expect(_titles(tester), ['Big Alpha', 'Alto']);
    expect(h.container.read(settingsProvider).albumSort, saved);
  });

  testWidgets('the view toggle writes the shared setting', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    expect(find.byType(AlbumGridTile), findsNWidgets(2));

    await _toList(tester, h);
    expect(find.byType(AlbumListTile), findsNWidgets(2));
    expect(find.byType(AlbumGridTile), findsNothing);
  });

  testWidgets('list rows show song totals on Albums, not on the others', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    await _toList(tester, h);
    expect(find.textContaining('2 songs'), findsOneWidget);

    goTo(tester, h, _annAppearsOn);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumListTile), findsNWidgets(2));
    expect(_songTotals, findsNothing);
  });

  testWidgets('a genre list has no song totals either', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _rock, location: _rockAlbums);
    await _toList(tester, h);

    expect(find.byType(AlbumListTile), findsNWidgets(2));
    expect(_songTotals, findsNothing);
  });

  testWidgets('Ctrl+F opens the filter of the list on top', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);

    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsOneWidget);
    expect(find.text('Filter albums'), findsOneWidget);
  });

  testWidgets('a reload keeps the sort, the filter and the subtitle', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    await tester.tap(find.byTooltip('Order: Ascending'));
    await tester.pumpAndSettle();
    await _filterBy(tester, 'ann');
    expect(_titles(tester), ['Alpha', 'Zeta']);

    await insertTracks(tester, h, const [
      TestTrack('b1', artist: 'Ann', album: 'Beta', albumArtist: 'Ann'),
    ]);
    await settleIo(tester, h);

    expect(find.text('Ann · 3 / 3 albums'), findsOneWidget);
    expect(tester.widget<TextField>(_filterField).controller?.text, 'ann');
    // Year, descending; the new album has no year, so it comes last.
    expect(_titles(tester), ['Alpha', 'Zeta', 'Beta']);
  });

  testWidgets('a section emptied while filtered closes the filter', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAppearsOn);
    await _filterBy(tester, 'bob');

    await tester.runAsync(() async {
      final rows = await h.db.select(h.db.tracks).get();
      await h.db.deleteTracksById([
        for (final r in rows)
          if (r.title == 't1' || r.title == 'o1') r.id,
      ]);
    });
    await settleIo(tester, h);

    expect(find.byType(InPageSearchBox), findsNothing);
    expect(find.text('No albums here any more'), findsOneWidget);
    expect(find.text('Ann · 0 albums'), findsOneWidget);
  });

  testWidgets('a tap opens the album under the list, in Artists', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    final key = tester
        .widget<AlbumGridTile>(find.byType(AlbumGridTile).first)
        .data
        .key;

    await tester.tap(find.text('Zeta'));
    await tester.pumpAndSettle();

    expect(location(h), albumUnderLocation(_annAlbums, key));
    expect(_shellIndex(tester), AppDestination.artists.index);
  });

  testWidgets('a genre album opens in Genres, from the list or the page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _rock, location: _rockAlbums);
    final key = tester
        .widget<AlbumGridTile>(find.byType(AlbumGridTile).first)
        .data
        .key;

    await tester.tap(find.text('Loud'));
    await tester.pumpAndSettle();
    expect(location(h), albumUnderLocation(_rockAlbums, key));
    expect(_shellIndex(tester), AppDestination.genres.index);

    goTo(tester, h, albumUnderLocation(genreLocation('rock'), key));
    await tester.pumpAndSettle();
    expect(find.text('r1'), findsOneWidget);
    expect(_shellIndex(tester), AppDestination.genres.index);
  });

  testWidgets('a broken key or a vanished owner shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: '/artists/!!/albums');
    expect(find.text('Artist not found'), findsOneWidget);

    goTo(tester, h, '/genres/!!/albums');
    await tester.pumpAndSettle();
    expect(find.text('Genre not found'), findsOneWidget);

    goTo(tester, h, _annAlbums);
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    await tester.runAsync(() async {
      final rows = await h.db.select(h.db.tracks).get();
      await h.db.deleteTracksById([for (final r in rows) r.id]);
    });
    await settleIo(tester, h);
    expect(find.text('Artist not found'), findsOneWidget);
  });

  testWidgets('a genre whose songs are all gone shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _rock, location: _rockAlbums);
    expect(_titles(tester), ['Loud', 'Quiet']);

    await tester.runAsync(() async {
      final rows = await h.db.select(h.db.tracks).get();
      await h.db.deleteTracksById([
        for (final r in rows)
          if (r.title.startsWith('r')) r.id,
      ]);
    });
    await settleIo(tester, h);

    expect(find.text('Genre not found'), findsOneWidget);
  });

  testWidgets('a failed read is logged once, not by the list and the page', (
    tester,
  ) async {
    final severe = <LogRecord>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level >= Level.SEVERE)
        .listen(severe.add);
    addTearDown(sub.cancel);
    final h = LibraryHarness(
      overrides: [
        artistPageProvider.overrideWith(
          (ref, key) => Stream.error(StateError('boom')),
        ),
      ],
    );
    await openWithTracks(tester, h, const [], location: _annAlbums);

    expect(find.text("Couldn't open the library"), findsOneWidget);
    expect(severe, hasLength(1));
    expect(severe.single.message, 'Reading the artist failed');
  });

  testWidgets('the open filter box stays usable in a narrow window', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _ann, location: _annAlbums);
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();

    expect(tester.getSize(_filterField).width, greaterThanOrEqualTo(180));
  });
}
