import 'package:flutter_test/flutter_test.dart';
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
          onQueueAction: (_) {},
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
