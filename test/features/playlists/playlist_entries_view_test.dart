import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/playlist_entry_placeholder.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'playlist_entries_view_harness.dart';
import 'playlist_test_data.dart' show hoverRow;

void main() {
  final view = EntriesViewHarness();
  setUp(view.reset);

  group('rows', () {
    testWidgets('show title, artist and album, and duration', (tester) async {
      await view.pump(tester, [available(1), available(2)]);

      expect(find.text('T1'), findsOneWidget);
      expect(find.text('Artist 1'), findsOneWidget);
      expect(find.text('Album 1'), findsOneWidget);
      expect(find.text('1:02'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
    });

    testWidgets('an entry outside the library shows its file name, no play', (
      tester,
    ) async {
      await view.pump(tester, [missing(1), available(2)]);

      expect(find.text('lost1.mp3'), findsOneWidget);
      expect(find.text('Not in library'), findsOneWidget);

      await tester.tap(find.text('lost1.mp3'));
      await tester.pump();
      expect(view.played, isEmpty);

      await tester.tap(find.text('T2'));
      await tester.pump();
      expect(view.played, [(2, 1)], reason: 'by entry id, with its index');
    });

    testWidgets('only a playable row has a queue menu', (tester) async {
      await view.pump(tester, [
        missing(1),
        available(2),
      ], onEntryQueueAction: (_, _) {});

      final tiles = find.byType(PlaylistEntryTile);
      await tester.longPress(tiles.at(0));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsNothing);

      await tester.longPress(tiles.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
    });

    testWidgets('the remove button reports the entry id', (tester) async {
      await view.pump(tester, [available(1), available(2)]);

      await hoverRow(tester, 1);
      await tester.tap(find.byTooltip('Remove from playlist').last);

      expect(view.removed, [2]);
    });

    testWidgets('without callbacks rows have no handle and no remove button', (
      tester,
    ) async {
      await view.pump(tester, [available(1), available(2)], readOnly: true);

      expect(find.byType(PlaylistEntryTile), findsNWidgets(2));
      expect(find.byTooltip('Remove from playlist'), findsNothing);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    });

    testWidgets('an empty playlist shows the empty state', (tester) async {
      await view.pump(tester, const []);

      expect(find.text('This playlist is empty'), findsOneWidget);
      expect(find.byType(PlaylistEntryTile), findsNothing);
    });

    testWidgets('an empty Favorites playlist says how to fill it', (
      tester,
    ) async {
      await view.pump(tester, const [], favorites: true);

      expect(find.text('Songs you like will show up here.'), findsOneWidget);
    });

    testWidgets('only the rows in view are read, the rest are slots', (
      tester,
    ) async {
      await view.pump(tester, [for (var i = 0; i < 250; i++) available(i)]);

      expect(find.text('250 songs'), findsOneWidget);
      expect(view.loads, [(0, 100)], reason: 'one page, not 250 rows');
      expect(find.byType(PlaylistEntryPlaceholder), findsNothing);
    });

    for (final width in [480.0, 1280.0]) {
      testWidgets('lays out at $width px without overflow', (tester) async {
        await view.pump(
          tester,
          [available(1), missing(2)],
          name: 'A very long playlist name that needs two lines at least',
          width: width,
          onQueueAction: (_) {},
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('header', () {
    testWidgets('Play asks for the first playable entry', (tester) async {
      await view.pump(tester, [missing(1), available(2)]);

      await tester.tap(find.text('Play'));
      await tester.pump();

      expect(view.played, [(null, 0)]);
    });

    testWidgets('Play is disabled when nothing can play', (tester) async {
      await view.pump(tester, [missing(1)]);

      final play = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Play'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(play.onPressed, isNull);
    });

    testWidgets('the playlist menu has its own icon beside the queue menu', (
      tester,
    ) async {
      await view.pump(tester, [available(1)], onQueueAction: (_) {});

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byTooltip('Playlist actions'), findsOneWidget);
    });

    testWidgets('the queue button is hidden when nothing can play', (
      tester,
    ) async {
      await view.pump(tester, [missing(1)], onQueueAction: (_) {});

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('the queue menu reports the action picked', (tester) async {
      QueueAction? received;
      await view.pump(tester, [
        available(1),
        available(2),
      ], onQueueAction: (action) => received = action);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue'));
      await tester.pumpAndSettle();

      expect(received, QueueAction.addToQueue);
    });

    testWidgets('the menu renames and deletes', (tester) async {
      await view.pump(tester, [available(1)]);

      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(view.renamed, 1);

      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      expect(view.deleted, 1);
    });
  });
}
