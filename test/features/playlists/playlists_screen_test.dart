import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_writes.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/playlists/collage_list_row.dart';
import 'package:kanaru/features/playlists/playlists_grid.dart';
import 'package:kanaru/features/playlists/playlists_list.dart';
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

  group('list view', () {
    Finder inList(Finder finder) =>
        find.descendant(of: find.byType(PlaylistsList), matching: finder);

    Future<void> openPlaylists(WidgetTester tester, LibraryHarness h) async {
      goTo(tester, h, '/playlists');
      await settleDb(tester);
    }

    testWidgets('opens as a grid and the toggle switches to rows', (
      tester,
    ) async {
      await openApp(tester, h, ['Alpha', 'Bravo']);
      await seedPlaylist(tester, h, 'Old', ['Alpha', 'Bravo'], now: 1);
      await seedPlaylist(tester, h, 'New', const [], now: 2);
      await openPlaylists(tester, h);

      expect(find.byType(PlaylistsGrid), findsOneWidget);
      expect(find.byType(PlaylistsList), findsNothing);

      // The icon shows the current view; a tap switches to the other one.
      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistsGrid), findsNothing);
      expect(find.byType(CollageListRow<void>), findsNWidgets(2));
      expect(inList(find.text('2 songs')), findsOneWidget);
      expect(inList(find.text('No songs')), findsOneWidget);
      // Newest first.
      expect(
        tester.getTopLeft(inList(find.text('New'))).dy,
        lessThan(tester.getTopLeft(inList(find.text('Old'))).dy),
      );
      expect(h.container.read(settingsProvider).playlistsView, AlbumsView.list);

      await tester.tap(find.byTooltip('List'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsGrid), findsOneWidget);
    });

    testWidgets('a row opens its playlist', (tester) async {
      await openApp(tester, h, ['Alpha']);
      final id = await seedPlaylist(tester, h, 'Mix', ['Alpha']);
      await openPlaylists(tester, h);
      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();

      await tester.tap(inList(find.text('Mix')));
      await settleDb(tester);

      expect(location(h), '/playlists/$id');
    });

    testWidgets('tapping the toggle saves the choice and a restart keeps it', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('playlists_view');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = SettingsFile('${dir.path}/settings.json');
      final first = LibraryHarness(
        refreshInterval: Duration.zero,
        overrides: [settingsFileProvider.overrideWithValue(file)],
      );
      await openApp(tester, first, ['Alpha']);
      await seedPlaylist(tester, first, 'Mix', ['Alpha']);
      await openPlaylists(tester, first);

      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();
      // The write is real file I/O started inside the fake clock: let real
      // time pass, then pump so its completion callbacks run.
      final saved = File('${dir.path}/settings.json');
      for (var i = 0; i < 100; i++) {
        if (saved.existsSync() &&
            saved.readAsStringSync().contains('"playlistsView": "list"')) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        File('${dir.path}/settings.json').readAsStringSync(),
        contains('"playlistsView": "list"'),
      );

      // Close the first run (its providers dispose on a timer) before the
      // next one starts from what the file holds.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final restarted = LibraryHarness(
        overrides: [initialSettingsProvider.overrideWithValue(file.load())],
      );
      await openApp(tester, restarted, ['Alpha']);
      await seedPlaylist(tester, restarted, 'Mix', ['Alpha']);
      await openPlaylists(tester, restarted);

      expect(find.byType(PlaylistsList), findsOneWidget);
      expect(find.byType(PlaylistsGrid), findsNothing);
    });

    testWidgets('the toggle is hidden with no playlists', (tester) async {
      await openApp(tester, h, ['Alpha']);
      await openPlaylists(tester, h);

      expect(find.byTooltip('Grid'), findsNothing);
      expect(find.byTooltip('List'), findsNothing);

      await tester.runAsync(() => h.db.createPlaylist('Later', now: 5));
      await settleDb(tester);
      expect(find.byTooltip('Grid'), findsOneWidget);
    });

    testWidgets('with none it shows the empty state and creates', (
      tester,
    ) async {
      await openApp(tester, h, ['Alpha']);
      h.container
          .read(settingsProvider.notifier)
          .setPlaylistsView(AlbumsView.list);
      await openPlaylists(tester, h);

      expect(
        find.text('Create a playlist to keep songs in your own order.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'New playlist').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleDb(tester);

      expect(location(h), startsWith('/playlists/'));
    });

    for (final view in AlbumsView.values) {
      testWidgets('the header keeps New and Import in the ${view.name} view', (
        tester,
      ) async {
        await openApp(tester, h, ['Alpha']);
        await seedPlaylist(tester, h, 'Mix', ['Alpha']);
        h.container.read(settingsProvider.notifier).setPlaylistsView(view);
        await openPlaylists(tester, h);

        expect(find.widgetWithText(FilledButton, 'New playlist'), findsOne);
        expect(find.text('Import M3U…'), findsOneWidget);
      });
    }
  });
}
