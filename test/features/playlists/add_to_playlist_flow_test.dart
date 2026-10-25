import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/library/albums/album_screen.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart'
    show TestTrack, goTo, insertTracks, openWithTracks;
import '../library/library_test_harness.dart';
import '../search/search_test_data.dart' show openSearch;
import 'add_to_playlist_test_support.dart';
import 'playlist_test_data.dart';

const _alpha = AlbumKey('ann', 'alpha');

const _album = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('a3', artist: 'Ann', album: 'Alpha', track: 3),
];

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<List<String>> titlesIn(WidgetTester tester, int id) async {
    final page = await tester.runAsync(() => h.db.playlistPage(id));
    return [for (final e in page!.entries) e.track?.title ?? e.path];
  }

  group('existing playlist', () {
    testWidgets('adds a song, then says it is already there', (tester) async {
      await openApp(tester, h, ['a', 'b'], location: '/songs');
      final id = await seedPlaylist(tester, h, 'Mix', const []);
      await settleDb(tester);

      await addVia(tester, h, find.text('a'), 'Mix');

      expect(picker, findsNothing);
      expect(find.text('Added to Mix: a'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a']);
      await clearMessage(tester);

      await addVia(tester, h, find.text('a'), 'Mix');

      expect(picker, findsNothing, reason: 'no duplicate dialog either');
      expect(find.text('Already in Mix: a'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a']);
    });

    testWidgets('an album with one song already there adds the rest', (
      tester,
    ) async {
      await openApp(tester, h, [], location: '/home');
      await insertTracks(tester, h, _album);
      final id = await seedPlaylist(tester, h, 'Mix', ['a2']);
      goTo(tester, h, '/albums');
      await settleDb(tester);

      await addVia(tester, h, find.text('Alpha'), 'Mix');

      expect(picker, findsNothing);
      expect(
        find.text('Added 2 songs to Mix, 1 was already there'),
        findsOneWidget,
      );
      expect(await titlesIn(tester, id), ['a2', 'a1', 'a3']);
    });

    testWidgets('an album that is all there writes nothing', (tester) async {
      await openApp(tester, h, [], location: '/home');
      await insertTracks(tester, h, _album);
      final id = await seedPlaylist(tester, h, 'Mix', ['a1', 'a2', 'a3']);
      goTo(tester, h, '/albums');
      await settleDb(tester);

      await addVia(tester, h, find.text('Alpha'), 'Mix');

      expect(find.text('Already in Mix: Alpha'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a1', 'a2', 'a3']);
    });

    testWidgets('copies already stored twice are left alone', (tester) async {
      await openApp(tester, h, ['a'], location: '/songs');
      final id = await seedPlaylist(tester, h, 'Twice', ['a', 'a']);
      await settleDb(tester);

      await addVia(tester, h, find.text('a'), 'Twice');

      expect(find.text('Already in Twice: a'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a', 'a']);
    });
  });

  group('new playlist', () {
    testWidgets('is created with the song and listed afterwards', (
      tester,
    ) async {
      await openApp(tester, h, ['a'], location: '/songs');

      await openMenuOf(tester, find.text('a'));
      await tester.tap(find.text('Add to playlist…'));
      await tester.pumpAndSettle();
      await tester.tap(inPicker('New playlist…'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Road trip');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleDb(tester);

      expect(find.text('Added to Road trip: a'), findsOneWidget);
      final rows = await tester.runAsync(
        () => h.db.watchPlaylistSummaries().first,
      );
      expect(rows!.single.name, 'Road trip');
      expect(await titlesIn(tester, rows.single.id), ['a']);
    });

    testWidgets('a repeated path in the batch is stored once', (tester) async {
      await openApp(tester, h, ['a'], location: '/home');
      final twice = await seedPlaylist(tester, h, 'Dup', ['a', 'a']);
      goTo(tester, h, '/playlists/$twice');
      await settleDb(tester);

      await tester.tap(find.byTooltip('Queue actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to playlist…'));
      await tester.pumpAndSettle();
      await tester.tap(inPicker('New playlist…'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Copy');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleDb(tester);

      final rows = await tester.runAsync(
        () => h.db.watchPlaylistSummaries().first,
      );
      final copy = rows!.firstWhere((p) => p.name == 'Copy');
      expect(await titlesIn(tester, copy.id), ['a']);
    });

    testWidgets('cancelling the name creates nothing', (tester) async {
      await openApp(tester, h, ['a'], location: '/songs');

      await openMenuOf(tester, find.text('a'));
      await tester.tap(find.text('Add to playlist…'));
      await tester.pumpAndSettle();
      await tester.tap(inPicker('New playlist…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await settleDb(tester);

      final rows = await tester.runAsync(
        () => h.db.watchPlaylistSummaries().first,
      );
      expect(rows, isEmpty);
    });
  });

  group('picker', () {
    testWidgets('Esc adds nothing and says nothing', (tester) async {
      await openApp(tester, h, ['a'], location: '/songs');
      final id = await seedPlaylist(tester, h, 'Mix', const []);
      await settleDb(tester);

      await openMenuOf(tester, find.text('a'));
      await tester.tap(find.text('Add to playlist…'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleDb(tester);

      expect(picker, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(await titlesIn(tester, id), isEmpty);
    });

    testWidgets('still adds when the row is gone while it is open', (
      tester,
    ) async {
      await openWithTracks(tester, h, _album, location: albumLocation(_alpha));
      final id = await seedPlaylist(tester, h, 'Mix', const []);
      await settleDb(tester);

      await openMenuOf(tester, find.text('a2'));
      await tester.tap(find.text('Add to playlist…'));
      await tester.pumpAndSettle();
      // Same branch: the album page and its rows are really disposed.
      goTo(tester, h, '/albums');
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsNothing);
      expect(picker, findsOneWidget);

      await tester.tap(inPicker('Mix'));
      await settleDb(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Added to Mix: a2'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a2']);
    });
  });

  testWidgets('a failed save says so', (tester) async {
    await openApp(tester, h, ['a'], location: '/songs');
    await seedPlaylist(tester, h, 'Mix', const []);
    await breakWrites(tester, h, 'playlist_entries', 'INSERT');
    await settleDb(tester);

    await addVia(tester, h, find.text('a'), 'Mix');

    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsOneWidget,
    );
  });

  group('other sources', () {
    testWidgets('an artist row adds all their songs', (tester) async {
      await openWithTracks(tester, h, _album, location: '/artists');
      final id = await seedPlaylist(tester, h, 'Mix', const []);
      await settleDb(tester);

      await addVia(tester, h, find.text('Ann'), 'Mix');

      expect(find.text('Added to Mix: Ann'), findsOneWidget);
      expect(await titlesIn(tester, id), ['a1', 'a2', 'a3']);
    });

    testWidgets('a search result adds that song', (tester) async {
      await openSearch(tester, h, 'adele');
      final id = await seedPlaylist(tester, h, 'Mix', const []);
      await settleDb(tester);

      await addVia(tester, h, find.text('Hello'), 'Mix');

      expect(find.text('Added to Mix: Hello'), findsOneWidget);
      expect(await titlesIn(tester, id), ['Hello']);
    });

    testWidgets('a row of another playlist adds that song', (tester) async {
      await openApp(tester, h, ['a', 'b']);
      final from = await seedPlaylist(tester, h, 'From', ['a', 'b']);
      final to = await seedPlaylist(tester, h, 'To', const [], now: 2);
      goTo(tester, h, '/playlists/$from');
      await settleDb(tester);

      await addVia(tester, h, find.text('b'), 'To');

      expect(find.text('Added to To: b'), findsOneWidget);
      expect(await titlesIn(tester, to), ['b']);
      expect(await titlesIn(tester, from), ['a', 'b']);
    });
  });

  testWidgets('a message about an earlier add gives way to the next', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b'], location: '/songs');
    await seedPlaylist(tester, h, 'Mix', const []);
    await settleDb(tester);

    await addVia(tester, h, find.text('a'), 'Mix');
    expect(find.text('Added to Mix: a'), findsOneWidget);
    await addVia(tester, h, find.text('b'), 'Mix');

    expect(find.text('Added to Mix: b'), findsOneWidget);
    expect(find.text('Added to Mix: a'), findsNothing);
  });

  testWidgets('a failed create says so once and adds nothing', (tester) async {
    await openApp(tester, h, ['a'], location: '/songs');
    await breakWrites(tester, h, 'playlists', 'INSERT');
    await settleDb(tester);

    await openMenuOf(tester, find.text('a'));
    await tester.tap(find.text('Add to playlist…'));
    await tester.pumpAndSettle();
    await tester.tap(inPicker('New playlist…'));
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Road trip');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settleDb(tester);

    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsOneWidget,
    );
    expect(find.textContaining('Added to'), findsNothing);
    final rows = await tester.runAsync(
      () => h.db.watchPlaylistSummaries().first,
    );
    expect(rows, isEmpty);
  });
}
