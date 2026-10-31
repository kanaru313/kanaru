import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_entry_placeholder.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import 'playlist_entries_view_harness.dart';
import 'playlist_test_data.dart' show removeRowViaModal;

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

    testWidgets('Remove from playlist in the modal reports the entry id', (
      tester,
    ) async {
      view.rowModals = true;
      await view.pump(tester, [available(1), available(2)]);

      await removeRowViaModal(tester, 1);

      expect(view.removed, [2]);
    });

    testWidgets('removing the second copy of a file removes only that entry', (
      tester,
    ) async {
      final copy = PlaylistEntryRow(
        entryId: 9,
        path: available(1).path,
        track: available(1).track,
      );
      view.rowModals = true;
      await view.pump(tester, [available(1), copy]);

      await removeRowViaModal(tester, 1);

      expect(view.removed, [9]);
    });

    testWidgets('Remove from playlist is red and rows have no remove button', (
      tester,
    ) async {
      view.rowModals = true;
      await view.pump(tester, [available(1)]);
      expect(find.byTooltip('Remove from playlist'), findsNothing);

      await tester.tap(
        find.byType(PlaylistEntryTile),
        buttons: kSecondaryButton,
      );
      await settleSongModal(tester);

      final error = Theme.of(tester.element(find.byType(PlaylistEntryTile)))
          .colorScheme
          .error;
      final action = modalAction('remove-from-playlist');
      expect(action, findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: action, matching: find.byType(Icon)).first,
            )
            .color,
        error,
      );
      final label = find.descendant(
        of: action,
        matching: find.text('Remove from playlist'),
      );
      expect(
        tester.widget<Text>(label).style?.color ??
            DefaultTextStyle.of(tester.element(label)).style.color,
        error,
      );
    });

    testWidgets('the modal of a read-only list has no Remove', (tester) async {
      view.rowModals = true;
      await view.pump(tester, [available(1)], readOnly: true);

      await tester.tap(
        find.byType(PlaylistEntryTile),
        buttons: kSecondaryButton,
      );
      await settleSongModal(tester);

      expect(find.text('Go to artist'), findsOneWidget);
      expect(modalAction('remove-from-playlist'), findsNothing);
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

    testWidgets('one more button holds the playlist and queue actions', (
      tester,
    ) async {
      await view.pump(tester, [available(1)], onQueueAction: (_) {});

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byTooltip('Playlist actions'), findsOneWidget);
      expect(find.byIcon(AppIcons.edit), findsNothing);
    });

    testWidgets('the menu keeps Rename and Delete when nothing can play', (
      tester,
    ) async {
      await view.pump(tester, [missing(1)], onQueueAction: (_) {});

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Add to queue'), findsNothing);
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
