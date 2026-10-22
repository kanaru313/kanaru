import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';

import 'playlist_entries_view_harness.dart';

void main() {
  final view = EntriesViewHarness();
  setUp(view.reset);

  group('reorder', () {
    final rows = [available(0), available(1), available(2)];

    testWidgets('a drop reports the entry and its final index at once', (
      tester,
    ) async {
      await view.pump(tester, pageOf(rows));

      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);

      expect(view.moves, [(0, 2)]);
      expect(view.shownIds(tester), [1, 2, 0], reason: 'before the write ends');
    });

    testWidgets('a failed write puts the rows back', (tester) async {
      await view.pump(tester, pageOf(rows));
      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);

      await view.finishMove(tester, ok: false);

      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('keeps the new order when the same page is shown again', (
      tester,
    ) async {
      final old = pageOf(rows);
      await view.pump(tester, old);
      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);

      await view.finishMove(tester, ok: true);
      expect(view.shownIds(tester), [1, 2, 0]);

      // A reload state renders the previous page object once more.
      await view.pump(tester, old);
      expect(view.shownIds(tester), [1, 2, 0], reason: 'not the old order');

      // The stream catches up with the moved order.
      await view.pump(tester, pageOf([rows[1], rows[2], rows[0]]));
      expect(view.shownIds(tester), [1, 2, 0]);
    });

    testWidgets('a drop while a move is saving is ignored', (tester) async {
      await view.pump(tester, pageOf(rows));
      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);
      expect(view.shownIds(tester), [1, 2, 0]);

      await view.dragHandle(tester, view.handle(2), -playlistEntryExtent);

      expect(view.moves, [(0, 2)], reason: 'no second write');
      expect(view.shownIds(tester), [1, 2, 0]);

      await view.finishMove(tester, ok: false);
      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('a move that throws puts the rows back', (tester) async {
      view.moveError = StateError('gone');
      await view.pump(tester, pageOf(rows));
      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('a tap during the move plays the order on screen', (
      tester,
    ) async {
      await view.pump(tester, pageOf(rows));
      await view.dragHandle(tester, view.handle(0), 2 * playlistEntryExtent);

      await tester.tap(find.text('T1'));

      expect(view.playedIndex, 0);
      expect(view.playedRows!.map((e) => e.entryId), [1, 2, 0]);
    });
  });
}
