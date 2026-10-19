import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/albums/album_grid_tile.dart';
import 'package:kanaru/features/library/albums/album_list_tile.dart';
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

    await tester.tap(find.widgetWithText(TextButton, 'Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Descending'));
    await tester.pumpAndSettle();
    expect(left('Alpha'), lessThan(left('Beta')));
    expect(h.container.read(settingsProvider).albumSort.descending, isTrue);
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
    final ascending = radio<bool>('Ascending');
    expect(ascending.groupValue, ascending.value);
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

  testWidgets('switches to the list view and saves it', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumListTile), findsNWidgets(3));
    expect(find.text('Amy · 2005 · 1 song'), findsOneWidget);
    expect(h.container.read(settingsProvider).albumsView, AlbumsView.list);
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
