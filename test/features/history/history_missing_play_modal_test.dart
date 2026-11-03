import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_row_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import '../../support/settle_modal.dart';
import 'history_test_harness.dart';

DateTime _at(int day, [int hour = 9]) => DateTime(2026, 10, day, hour);

/// The "date - time" text of the only journal row, as the row draws it.
String _rowText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(HistoryPlayRowTile),
        matching: find.textContaining(' - '),
      ),
    )
    .data!;

Future<int> _playCount(WidgetTester tester, LibraryHarness h) async =>
    (await tester.runAsync(() => h.db.select(h.db.plays).get()))!.length;

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  group('journal row', () {
    historyTestWidgets('header names the file and has no played chip', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23))]);
      final rowText = _rowText(tester);

      await tester.tap(find.text('gone.flac'), buttons: kSecondaryButton);
      await settleModal(tester);

      expect(find.byIcon(AppIcons.musicOff), findsWidgets);
      expect(find.text('gone.flac'), findsWidgets);
      expect(find.text('Not in library'), findsWidgets);
      expect(find.text('Played $rowText'), findsNothing);
    });

    historyTestWidgets('Song history opens the journal song page', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23))]);

      await tester.tap(find.text('gone.flac'), buttons: kSecondaryButton);
      await settleModal(tester);
      await tester.tap(find.text('Song history'));
      await settleHistory(tester);

      expect(location(h), historyTrackLocation('/m/gone.flac'));
    });

    historyTestWidgets('Remove deletes the play and Undo restores it', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23))]);

      await tester.tap(find.text('gone.flac'), buttons: kSecondaryButton);
      await settleModal(tester);
      await tester.tap(find.text('Remove from history'));
      await settleModal(tester);
      await settleHistory(tester);
      expect(await _playCount(tester, h), 0);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settleHistory(tester);
      expect(await _playCount(tester, h), 1);
    });

    historyTestWidgets('the Menu key opens it and focuses a row', (
      tester,
    ) async {
      await openHistory(tester, h, plays: [('gone', _at(23))]);

      Focus.of(tester.element(find.byType(SongRowView))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleModal(tester);

      expect(find.text('Not in library'), findsWidgets);
      expect(find.text('Remove from history'), findsOneWidget);
    });
  });

  group('Most played row', () {
    historyTestWidgets('has the rank chip and Song history, no Remove', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        plays: [('Ghost', _at(10)), ('Ghost', _at(11)), ('Gone', _at(12))],
        page: mostPlayedPath,
      );

      await tester.longPress(find.byType(MostPlayedRowTile).at(1));
      await settleModal(tester);

      expect(find.text('#2 · 1 listen'), findsOneWidget);
      expect(find.text('Remove from history'), findsNothing);
      await tester.tap(find.text('Song history'));
      await settleHistory(tester);
      expect(location(h), mostPlayedTrackLocation('/m/Gone.flac'));
    });

    historyTestWidgets('the song modal of a library row shows the rank', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', _at(10)), ('A', _at(11)), ('B', _at(12))],
        page: mostPlayedPath,
      );

      await tester.longPress(find.byType(MostPlayedRowTile).at(1));
      await settleModal(tester);

      expect(find.text('#2 · 1 listen'), findsOneWidget);
    });
  });

  historyTestWidgets('the song modal of a library journal row has no '
      'played chip', (tester) async {
    await openHistory(tester, h, tracks: [song('A')], plays: [('A', _at(23))]);
    final rowText = _rowText(tester);

    await tester.tap(find.text('A').first, buttons: kSecondaryButton);
    await settleModal(tester);

    expect(find.text('Played $rowText'), findsNothing);
  });
}
