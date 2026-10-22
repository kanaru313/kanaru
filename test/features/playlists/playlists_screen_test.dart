import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_writes.dart';
import 'package:kanaru/features/playlists/playlists_grid.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show goTo, location;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Finder inGrid(Finder finder) =>
      find.descendant(of: find.byType(PlaylistsGrid), matching: finder);

  testWidgets('shows a card per playlist with its count, newest first', (
    tester,
  ) async {
    await openApp(tester, h, ['Alpha', 'Bravo']);
    await seedPlaylist(tester, h, 'Old', ['Alpha', 'Bravo'], now: 1);
    await seedPlaylist(tester, h, 'New', const [], now: 2);
    goTo(tester, h, '/playlists');
    await settleDb(tester);

    expect(inGrid(find.text('Old')), findsOneWidget);
    expect(inGrid(find.text('2 songs')), findsOneWidget);
    expect(inGrid(find.text('No songs')), findsOneWidget);
    expect(
      tester.getTopLeft(inGrid(find.text('New'))).dx,
      lessThan(tester.getTopLeft(inGrid(find.text('Old'))).dx),
    );
  });

  testWidgets('a card opens its playlist', (tester) async {
    await openApp(tester, h, ['Alpha']);
    final id = await seedPlaylist(tester, h, 'Mix', ['Alpha']);
    goTo(tester, h, '/playlists');
    await settleDb(tester);

    await tester.tap(inGrid(find.text('Mix')));
    await settleDb(tester);

    expect(location(h), '/playlists/$id');
  });

  testWidgets('a new playlist appears without leaving the page', (
    tester,
  ) async {
    await openApp(tester, h, ['Alpha']);
    goTo(tester, h, '/playlists');
    await settleDb(tester);
    expect(inGrid(find.text('Later')), findsNothing);

    await tester.runAsync(() => h.db.createPlaylist('Later', now: 5));
    await settleDb(tester);

    expect(inGrid(find.text('Later')), findsOneWidget);
  });

  testWidgets('with none it offers a New playlist button that creates', (
    tester,
  ) async {
    await openApp(tester, h, ['Alpha']);
    goTo(tester, h, '/playlists');
    await settleDb(tester);

    expect(
      find.text('Create a playlist to keep songs in your own order.'),
      findsOneWidget,
    );
    // The empty state's button, below the header's.
    await tester.tap(find.widgetWithText(FilledButton, 'New playlist').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Road trip',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(location(h), startsWith('/playlists/'));
    expect(find.text('This playlist is empty'), findsOneWidget);
  });

  testWidgets('the header button creates too', (tester) async {
    await openApp(tester, h, ['Alpha']);
    goTo(tester, h, '/playlists');
    await settleDb(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'New playlist').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(location(h), startsWith('/playlists/'));
  });
}
