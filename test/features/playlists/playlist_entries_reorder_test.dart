import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/playlist_entry_placeholder.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/playlist_side_pane.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart'
    show
        BorderRadius,
        BoxDecoration,
        CustomScrollView,
        DecoratedBox,
        IconButton,
        Icons,
        Scrollable,
        ScrollableState,
        SizedBox;

import 'playlist_entries_view_harness.dart';
import 'playlist_test_data.dart' show hoverRow, rowExtent;

void main() {
  final view = EntriesViewHarness();
  setUp(view.reset);

  group('reorder', () {
    final rows = [available(0), available(1), available(2)];

    testWidgets('a drop reports the entry and its final index at once', (
      tester,
    ) async {
      await view.pump(tester, rows);

      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      expect(view.moves, [(0, 2)]);
      expect(view.shownIds(tester), [1, 2, 0], reason: 'before the write ends');
    });

    testWidgets('the dragged row lifts as the card, not its padded slot', (
      tester,
    ) async {
      await view.pump(tester, rows);
      final slot = tester.getRect(find.byType(PlaylistEntryTile).first);

      final gesture = await tester.startGesture(
        tester.getCenter(view.handle(0)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump(const Duration(milliseconds: 16));

      // The cover card of the side pane has a shadow too; the lifted row is
      // the one in the overlay.
      final plate = find.byElementPredicate(
        (e) =>
            e.widget is DecoratedBox &&
            (e.widget as DecoratedBox).decoration is BoxDecoration &&
            ((e.widget as DecoratedBox).decoration as BoxDecoration)
                    .boxShadow !=
                null &&
            e.findAncestorWidgetOfExactType<PlaylistSidePane>() == null,
      );
      expect(plate, findsOneWidget);
      final card = tester.getSize(plate);
      expect(card.width, slot.width - 2 * songCardInset);
      expect(card.height, slot.height - songCardGap);
      final decoration =
          (tester.widget<DecoratedBox>(plate).decoration as BoxDecoration);
      expect(decoration.borderRadius, BorderRadius.circular(songCardRadius));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed write puts the rows back', (tester) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await view.finishMove(tester, ok: false);
      expect(view.settled, 1, reason: 'the owner reloads the head');
      await view.reloadHead(tester);

      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('keeps the new order when the same head is shown again', (
      tester,
    ) async {
      final old = headOf(rows);
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await view.finishMove(tester, ok: true);
      expect(view.shownIds(tester), [1, 2, 0]);

      // A reload state renders the previous head object once more.
      await view.showHead(tester, old, seq: 1);
      expect(view.shownIds(tester), [1, 2, 0], reason: 'not the old order');

      // The head read after the write has the moved order.
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [1, 2, 0]);
    });

    testWidgets('a head read before the write ended is ignored', (
      tester,
    ) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));
      await view.finishMove(tester, ok: true);

      // A new object, read before the settle: it would reset the rows to
      // what the old list order says.
      final reads = view.loads.length;
      await view.showHead(tester, headOf(rows), seq: view.minSeq - 1);
      expect(view.shownIds(tester), [1, 2, 0]);
      expect(view.loads, hasLength(reads), reason: 'no reread: stale head');

      await view.reloadHead(tester);
      expect(view.shownIds(tester), [1, 2, 0]);
      expect(view.loads, hasLength(reads + 1), reason: 'reread once');
    });

    testWidgets('a head that arrives mid-write is ignored', (tester) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await view.showHead(tester, headOf(rows));

      expect(view.shownIds(tester), [1, 2, 0]);
      expect(view.loads, [(0, 3)]);
    });

    testWidgets('a drop while a move is saving is ignored', (tester) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));
      expect(view.shownIds(tester), [1, 2, 0]);

      await view.dragHandle(tester, view.handle(2), -rowExtent(tester));

      expect(view.moves, [(0, 2)], reason: 'no second write');
      expect(view.shownIds(tester), [1, 2, 0]);

      await view.finishMove(tester, ok: false);
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('a move that throws puts the rows back', (tester) async {
      view.moveError = StateError('gone');
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(view.settled, 1);
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [0, 1, 2]);
    });

    testWidgets('a tap during the move plays only after it ends', (
      tester,
    ) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await tester.tap(find.text('T1'));
      await tester.pump();
      expect(view.played, isEmpty, reason: 'waits for the write');

      await view.finishMove(tester, ok: true);

      expect(view.played, [(1, 0)], reason: 'the row that was tapped');
    });

    testWidgets('a second tap while a play waits is ignored', (tester) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await tester.tap(find.text('T1'));
      await tester.tap(find.text('T2'));
      await tester.pump();
      await view.finishMove(tester, ok: true);

      expect(view.played, [(1, 0)]);
    });

    testWidgets('leaving the page while a play waits for a write is quiet', (
      tester,
    ) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));
      await tester.tap(find.text('T1'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await view.finishMove(tester, ok: true);

      expect(tester.takeException(), isNull);
      expect(view.played, isEmpty, reason: 'the page was gone');
    });

    Future<TestGesture> dragBy(WidgetTester tester, double dy) async {
      final gesture = await tester.startGesture(
        tester.getCenter(view.handle(0)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var moved = 0.0; moved < dy; moved += 8) {
        await gesture.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('a head during a drag waits, and the picked row is moved', (
      tester,
    ) async {
      await view.pump(tester, rows);
      final gesture = await dragBy(tester, 2 * rowExtent(tester));
      final reads = view.loads.length;

      // Meanwhile the database order changed under the row in hand.
      view.store = [rows[2], rows[1], rows[0]];
      await view.showHead(tester, headOf(view.store));
      expect(view.loads, hasLength(reads), reason: 'no read under the hand');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(view.moves, [(0, 2)], reason: 'the row that was picked up');
    });

    testWidgets('a head during a drag that goes nowhere is taken at the drop', (
      tester,
    ) async {
      await view.pump(tester, rows);
      // Past the touch slop, so the drag starts, but not into the next slot.
      final gesture = await dragBy(tester, 24);
      view.store = [rows[2], rows[1], rows[0]];
      await view.showHead(tester, headOf(view.store));
      expect(view.shownIds(tester), [0, 1, 2]);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(view.moves, isEmpty);
      expect(view.shownIds(tester), [2, 1, 0]);
    });

    testWidgets('a cancelled drag does not hold later heads back', (
      tester,
    ) async {
      await view.pump(tester, rows);
      final gesture = await dragBy(tester, 24);
      view.store = [rows[2], rows[1], rows[0]];
      await view.showHead(tester, headOf(view.store));
      expect(view.shownIds(tester), [0, 1, 2], reason: 'held during the drag');

      await gesture.cancel();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(); // the rows are read again
      expect(view.shownIds(tester), [2, 1, 0], reason: 'the head is taken');

      // Later heads are taken again: a failed removal rolls back on screen.
      await hoverRow(tester, 0);
      await tester.tap(find.byTooltip('Remove from playlist').at(0));
      await tester.pump();
      await view.finishRemove(tester, ok: false);
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [2, 1, 0]);
    });

    testWidgets('a drop back in the first slot takes the head that waited', (
      tester,
    ) async {
      await view.pump(tester, rows);
      // Down two slots and up again: the list reports the slot below the
      // row it started in.
      final down = 2 * rowExtent(tester);
      final gesture = await dragBy(tester, down);
      // Back up to within a few pixels of where the row started.
      for (var i = 0; i < (down - 32) ~/ 8; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      view.store = [rows[2], rows[1], rows[0]];
      await view.showHead(tester, headOf(view.store));
      expect(view.shownIds(tester), [0, 1, 2], reason: 'held during the drag');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(view.moves, isEmpty);
      expect(view.shownIds(tester), [2, 1, 0]);
    });
  });

  group('remove', () {
    final rows = [available(0), available(1), available(2)];

    testWidgets('the row goes at once and stays gone while saving', (
      tester,
    ) async {
      await view.pump(tester, rows);

      await hoverRow(tester, 1);
      await tester.tap(find.byTooltip('Remove from playlist').at(1));
      await tester.pump();

      expect(view.shownIds(tester), [0, 2]);
      expect(find.text('2 songs'), findsOneWidget);

      // The old head arrives while the write runs: not what is heading to
      // the screen.
      await view.showHead(tester, headOf(rows));
      expect(view.shownIds(tester), [0, 2]);
      expect(find.text('2 songs'), findsOneWidget);

      await view.finishRemove(tester, ok: true);
      expect(view.shownIds(tester), [0, 2]);
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [0, 2]);
      expect(find.text('2 songs'), findsOneWidget);
    });

    testWidgets('a failed removal brings the row back with the next head', (
      tester,
    ) async {
      await view.pump(tester, rows);
      await hoverRow(tester, 1);
      await tester.tap(find.byTooltip('Remove from playlist').at(1));
      await tester.pump();

      await view.finishRemove(tester, ok: false);
      await view.reloadHead(tester);

      expect(view.shownIds(tester), [0, 1, 2]);
      expect(find.text('3 songs'), findsOneWidget);
    });

    testWidgets('a removal while a move is saving is allowed', (tester) async {
      await view.pump(tester, rows);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));
      expect(view.shownIds(tester), [1, 2, 0]);

      await hoverRow(tester, 1);
      await tester.tap(find.byTooltip('Remove from playlist').at(1));
      await tester.pump();
      expect(view.removed, [2], reason: 'by entry id, not by index');
      expect(view.shownIds(tester), [1, 0]);

      await view.finishMove(tester, ok: true);
      await view.finishRemove(tester, ok: true);
      expect(view.settled, 1, reason: 'one settle for both writes');
      await view.reloadHead(tester);
      expect(view.shownIds(tester), [1, 0]);
    });

    testWidgets('two removals in one frame each take the right row', (
      tester,
    ) async {
      await view.pump(tester, [for (var i = 0; i < 4; i++) available(i)]);

      // Pressed straight through the buttons: no frame, and so no hover
      // change, between the two presses.
      // The hit-test path is covered by 'a hidden button does not take the tap'
      // in playlist_row_view_test.dart.
      void press(int row) => tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, AppIcons.closeRounded).at(row),
          )
          .onPressed!();
      press(0);
      press(2);
      await tester.pump();

      expect(view.removed, [0, 2]);
      expect(view.shownIds(tester), [1, 3]);
      expect(find.text('2 songs'), findsOneWidget);
    });

    testWidgets('removing the last row shows the empty state', (tester) async {
      await view.pump(tester, [available(0)]);

      await hoverRow(tester, 0);
      await tester.tap(find.byTooltip('Remove from playlist'));
      await tester.pump();

      expect(find.text('This playlist is empty'), findsOneWidget);
    });
  });

  group('slots', () {
    testWidgets('a row not read yet is a slot that cannot be dragged', (
      tester,
    ) async {
      await view.pump(tester, [for (var i = 0; i < 250; i++) available(i)]);
      // Page 0 is on screen; jump to a place whose page is not read.
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      scroll.position.jumpTo(150 * rowExtent(tester));
      await tester.pump();

      expect(find.byType(PlaylistEntryPlaceholder), findsWidgets);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(PlaylistEntryPlaceholder), findsNothing);
      expect(view.loads, [(0, 100), (100, 100)]);
    });
  });
}
