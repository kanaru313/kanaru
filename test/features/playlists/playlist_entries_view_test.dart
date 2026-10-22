import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'playlist_entries_view_harness.dart';

void main() {
  final view = EntriesViewHarness();
  setUp(view.reset);

  group('rows', () {
    testWidgets('show title, artist and album, and duration', (tester) async {
      await view.pump(tester, pageOf([available(1), available(2)]));

      expect(find.text('T1'), findsOneWidget);
      expect(find.text('Artist 1 · Album 1'), findsOneWidget);
      expect(find.text('1:02'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
    });

    testWidgets('an entry outside the library shows its file name, no play', (
      tester,
    ) async {
      await view.pump(tester, pageOf([missing(1), available(2)]));

      expect(find.text('lost1.mp3'), findsOneWidget);
      expect(find.text('Not in library'), findsOneWidget);

      await tester.tap(find.text('lost1.mp3'));
      expect(view.playedIndex, isNull);

      await tester.tap(find.text('T2'));
      expect(view.playedIndex, 1, reason: 'index in the shown rows');
      expect(view.playedRows!.map((e) => e.entryId), [1, 2]);
    });

    testWidgets('only a playable row has a queue menu', (tester) async {
      await view.pump(
        tester,
        pageOf([missing(1), available(2)]),
        onEntryQueueAction: (_, _) {},
      );

      final tiles = find.byType(PlaylistEntryTile);
      await tester.longPress(tiles.at(0));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsNothing);

      await tester.longPress(tiles.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
    });

    testWidgets('the remove button reports the entry id', (tester) async {
      await view.pump(tester, pageOf([available(1), available(2)]));

      await tester.tap(find.byTooltip('Remove from playlist').last);

      expect(view.removed, [2]);
    });

    testWidgets('an empty playlist shows the empty state', (tester) async {
      await view.pump(tester, pageOf(const []));

      expect(find.text('This playlist is empty'), findsOneWidget);
      expect(find.byType(PlaylistEntryTile), findsNothing);
    });

    for (final width in [480.0, 1280.0]) {
      testWidgets('lays out at $width px without overflow', (tester) async {
        await view.pump(
          tester,
          pageOf([
            available(1),
            missing(2),
          ], name: 'A very long playlist name that needs two lines at least'),
          width: width,
          onQueueAction: (_, _) {},
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('header', () {
    testWidgets('Play starts at the first playable entry', (tester) async {
      await view.pump(tester, pageOf([missing(1), available(2)]));

      await tester.tap(find.text('Play'));

      expect(view.playedIndex, 1);
    });

    testWidgets('Play is disabled when nothing can play', (tester) async {
      await view.pump(tester, pageOf([missing(1)]));

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
      await view.pump(tester, pageOf([available(1)]), onQueueAction: (_, _) {});

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byTooltip('Playlist actions'), findsOneWidget);
    });

    testWidgets('the queue button is hidden when nothing can play', (
      tester,
    ) async {
      await view.pump(tester, pageOf([missing(1)]), onQueueAction: (_, _) {});

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('the queue menu gets the rows as shown', (tester) async {
      List<PlaylistEntryRow>? received;
      await view.pump(
        tester,
        pageOf([available(1), available(2)]),
        onQueueAction: (rows, _) => received = rows,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue'));
      await tester.pumpAndSettle();

      expect(received!.map((e) => e.entryId), [1, 2]);
    });

    testWidgets('the menu renames and deletes', (tester) async {
      await view.pump(tester, pageOf([available(1)]));

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
