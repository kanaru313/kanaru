import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('one', artist: 'Zed', album: 'Beta', year: 1999),
  TestTrack('two', artist: 'Amy', album: 'Alpha', year: 2005),
  TestTrack('three', artist: 'Bob', album: 'Gamma', year: 1980),
  TestTrack('loose', artist: 'Bob'),
];

void main() {
  testWidgets('shows albums in a grid, sorted, and remembers the sort', (
    tester,
  ) async {
    double left(String text) => tester.getTopLeft(find.text(text)).dx;
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    expect(find.byType(AlbumGridTile), findsNWidgets(3));
    expect(find.text('Zed · 1999'), findsOneWidget);
    expect(left('Alpha'), lessThan(left('Beta')));
    expect(left('Beta'), lessThan(left('Gamma')));

    await tester.tap(find.widgetWithText(TextButton, 'Title'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Year'));
    await tester.pumpAndSettle();

    expect(left('Gamma'), lessThan(left('Beta')));
    expect(left('Beta'), lessThan(left('Alpha')));
    expect(
      h.container.read(settingsProvider).albumSort,
      const SortChoice(AlbumSortField.year),
    );

    await tester.tap(find.byTooltip('Order: Ascending'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Order: Descending'), findsOneWidget);
    expect(left('Alpha'), lessThan(left('Beta')));
    expect(h.container.read(settingsProvider).albumSort.descending, isTrue);
  });

  testWidgets('a grid tile is a card with its title 12 px from the edge', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    final tile = find.byType(AlbumGridTile).first;
    final card = tester.getRect(
      find.descendant(of: tile, matching: find.byType(Material)).first,
    );
    final cover = tester.getTopLeft(
      find.descendant(of: tile, matching: find.byType(AlbumArtwork)).first,
    );
    final title = tester.getTopLeft(
      find.descendant(of: tile, matching: find.text('Alpha')).first,
    );
    expect(cover.dx - card.left, 4);
    expect(title.dx - card.left, 12);
  });

  testWidgets('grid tiles fit large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    // An overflow would fail the test with a layout error.
    expect(find.byType(AlbumGridTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sort menu marks the current choice and refocuses', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    final button = find.widgetWithText(TextButton, 'Title');
    await tester.tap(button);
    await tester.pumpAndSettle();

    RadioMenuButton<T> radio<T>(String text) =>
        tester.widget(find.widgetWithText(RadioMenuButton<T>, text));
    final title = radio<AlbumSortField>('Title');
    expect(title.groupValue, title.value, reason: 'Title is checked');
    final year = radio<AlbumSortField>('Year');
    expect(year.groupValue, isNot(year.value));
    expect(
      tester.getSemantics(
        find.widgetWithText(RadioMenuButton<AlbumSortField>, 'Title'),
      ),
      isSemantics(isChecked: true),
    );

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    final focus = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Year'))
        .focusNode!;
    expect(focus.hasFocus, isTrue, reason: 'focus returns to the button');
  });

  testWidgets('the title row shows the sort field and arrow, no labels', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    expect(find.text('Sort by:'), findsNothing);
    expect(find.text('Order:'), findsNothing);
    final titleY = tester.getCenter(find.text('Albums').last).dy;
    expect(
      tester.getCenter(find.widgetWithText(TextButton, 'Title')).dy,
      moreOrLessEquals(titleY, epsilon: 1),
      reason: 'the sort sits on the title row',
    );
  });

  testWidgets('a narrow title row fits the sort controls', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    // The smallest window.
    tester.view.physicalSize = const Size(480, 720);
    await tester.pumpAndSettle();

    expect(find.text('Sort by:'), findsNothing);
    expect(find.text('Order:'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Title'), findsOneWidget);
    expect(find.byTooltip('Order: Ascending'), findsOneWidget);
    expect(find.byTooltip('Grid'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // An overflow would fail the test with a layout error.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to the list view and saves it', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    // The icon shows the current view; a tap switches to the other one.
    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumListTile), findsNWidgets(3));
    expect(find.text('Amy • 2005'), findsOneWidget);
    expect(h.container.read(settingsProvider).albumsView, AlbumsView.list);
    expect(find.byTooltip('List'), findsOneWidget);

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumGridTile), findsNWidgets(3));
    expect(h.container.read(settingsProvider).albumsView, AlbumsView.grid);
  });

  testWidgets('a new album shows up after the library changes', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks.take(1).toList(),
      location: '/albums',
    );
    expect(find.byType(AlbumGridTile), findsOneWidget);

    await insertTracks(tester, h, const [TestTrack('new', album: 'Delta')]);
    await tester.pumpAndSettle();

    expect(find.text('Delta'), findsOneWidget);
    expect(find.text('Unknown artist'), findsOneWidget);
  });

  testWidgets('empty states', (tester) async {
    final noRoots = LibraryHarness();
    await noRoots.pump(tester);
    goTo(tester, noRoots, '/albums');
    await tester.pumpAndSettle();
    expect(find.text('Add a music folder in Songs.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byTooltip('Order: Ascending'), findsNothing, reason: 'no sort');
    expect(find.widgetWithText(TextButton, 'Title'), findsNothing);
  });

  testWidgets('no albums yet', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('loose'),
    ], location: '/albums');
    expect(find.text('No albums yet'), findsOneWidget);
  });

  testWidgets('library unavailable', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the library"), findsOneWidget);
  });
}
