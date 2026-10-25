import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:kanaru/features/playlists/playlist_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show location;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

const _saveFailed = "Couldn't save the playlist. See the log for details.";

Future<void> openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Playlist actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

Finder get nameField => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  group('rename', () {
    testWidgets('from the menu', (tester) async {
      final id = await openMix(tester, h);

      await openMenu(tester, 'Rename');
      expect(tester.widget<TextField>(nameField).controller!.text, 'Mix');
      await tester.enterText(nameField, 'Road trip');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await settleDb(tester);

      // The page header and the sidebar row.
      expect(find.text('Road trip'), findsNWidgets(2));
      final summary = await tester.runAsync(() => h.db.playlistSummary(id));
      expect(summary!.name, 'Road trip');
    });

    testWidgets('a failed save says so and keeps the name', (tester) async {
      final id = await openMix(tester, h);
      await breakWrites(tester, h, 'playlists', 'UPDATE');

      await openMenu(tester, 'Rename');
      await tester.enterText(nameField, 'Road trip');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await settleDb(tester);

      expect(find.text(_saveFailed), findsOneWidget);
      final summary = await tester.runAsync(() => h.db.playlistSummary(id));
      expect(summary!.name, 'Mix');
    });
  });

  group('delete', () {
    testWidgets('leaves the page first and never shows "not found"', (
      tester,
    ) async {
      final id = await openMix(tester, h);
      // Watch the page the way the screen does, so the test can tell when
      // the reload after the delete has arrived.
      var reloadedAsGone = false;
      h.container.listen(playlistPageHeadProvider(id), (_, next) {
        if (next is AsyncData && next.value?.head == null) {
          reloadedAsGone = true;
        }
      });

      await openMenu(tester, 'Delete playlist');
      expect(find.text('Delete “Mix”?'), findsOneWidget);
      expect(find.textContaining('It has 4 songs.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));

      // Frames of zero length keep the leaving page mounted while the delete
      // and the reload happen, which is the case being tested.
      final sawNotFound = <bool>[];
      var mountedAfterReload = false;
      await pumpUntil(
        tester,
        () async => reloadedAsGone,
        frame: Duration.zero,
        onFrame: () {
          sawNotFound.add(
            find.text('Playlist not found').evaluate().isNotEmpty,
          );
          if (reloadedAsGone) {
            mountedAfterReload |= find
                .byType(PlaylistScreen)
                .evaluate()
                .isNotEmpty;
          }
        },
      );
      sawNotFound.add(find.text('Playlist not found').evaluate().isNotEmpty);
      mountedAfterReload |= find.byType(PlaylistScreen).evaluate().isNotEmpty;
      await settleDb(tester);

      expect(mountedAfterReload, isTrue, reason: 'the test saw the case');
      expect(sawNotFound, everyElement(isFalse));
      expect(location(h), '/playlists');
      expect(await tester.runAsync(() => h.db.playlistSummary(id)), isNull);
      expect(find.text('Mix'), findsNothing, reason: 'gone from the sidebar');
    });

    testWidgets('cancelling the confirmation keeps the playlist', (
      tester,
    ) async {
      final id = await openMix(tester, h);

      await openMenu(tester, 'Delete playlist');
      await tester.tap(find.text('Cancel'));
      await settleDb(tester);

      expect(location(h), '/playlists/$id');
      expect(await tester.runAsync(() => h.db.playlistSummary(id)), isNotNull);
    });

    testWidgets('a failure after leaving the page says so', (tester) async {
      final id = await openMix(tester, h);
      await breakWrites(tester, h, 'playlists', 'DELETE');

      await openMenu(tester, 'Delete playlist');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleDb(tester);

      expect(location(h), '/playlists');
      expect(find.text(_saveFailed), findsOneWidget);
      expect(await tester.runAsync(() => h.db.playlistSummary(id)), isNotNull);
      expect(find.text('Mix'), findsWidgets, reason: 'still listed');
    });
  });

  group('failed saves', () {
    testWidgets('a move goes back to the stored order and says so', (
      tester,
    ) async {
      final id = await openMix(tester, h);
      final paths = await storedPaths(tester, h, id);
      await breakWrites(tester, h, 'playlist_entries', 'UPDATE');

      await dragFirstRowDown(tester);
      await pumpUntil(
        tester,
        () async => find.text(_saveFailed).evaluate().isNotEmpty,
      );
      await settleDb(tester);

      expect(shownTitles(tester), mixTitles);
      expect(await storedPaths(tester, h, id), paths);
    });

    testWidgets('a removal keeps the row and says so', (tester) async {
      final id = await openMix(tester, h);
      await breakWrites(tester, h, 'playlist_entries', 'DELETE');

      await hoverRow(tester, 1);
      await tester.tap(find.byTooltip('Remove from playlist').at(1));
      await settleDb(tester);

      expect(find.text(_saveFailed), findsOneWidget);
      expect(shownTitles(tester), mixTitles);
      expect(find.text('4 songs'), findsOneWidget);
      expect(await storedPaths(tester, h, id), hasLength(4));
    });
  });
}
