import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_row_tile.dart';
import 'package:kanaru/features/history/history_track_play_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'history_test_harness.dart';

DateTime _at(int day, [int hour = 9]) => DateTime(2026, 10, day, hour);

/// Stores a play of [path] at [at], with [listenedMs] (null: unknown).
Future<int> _insert(
  WidgetTester tester,
  LibraryHarness h,
  String path,
  DateTime at, {
  int? listenedMs,
}) async {
  final id = await tester.runAsync(
    () => h.db
        .into(h.db.plays)
        .insert(
          PlaysCompanion.insert(
            path: path,
            playedAt: at.millisecondsSinceEpoch,
            listenedMs: Value(listenedMs),
          ),
        ),
  );
  return id!;
}

Future<Set<int>> _ids(WidgetTester tester, LibraryHarness h) async {
  final rows = await tester.runAsync(() => h.db.select(h.db.plays).get());
  return {for (final Play p in rows!) p.id};
}

Future<void> _menuOfRow(WidgetTester tester, int index, String item) async {
  await tester.tap(find.byTooltip('More').at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
  await settleHistory(tester);
}

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

Finder get _play => find.widgetWithText(FilledButton, 'Play');

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  group('opening', () {
    historyTestWidgets(
      'from the journal menu, with the totals and every play',
      (tester) async {
        await openHistory(
          tester,
          h,
          tracks: [song('A')],
          plays: [('A', _at(20)), ('A', _at(21)), ('A', _at(22))],
        );

        // The journal's rows have no more button: right click opens the menu.
        await tester.tap(find.text('A').first, buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Song history'));
        await tester.pumpAndSettle();
        await settleHistory(tester);

        expect(location(h), historyTrackLocation('/m/A.flac'));
        expect(
          find.text('3 listens · First Tue, Oct 20 · Last Thu, Oct 22 9:00 AM'),
          findsOneWidget,
        );
        expect(find.text('A'), findsOneWidget);
        // Newest first, counting down.
        final tiles = tester.widgetList<HistoryTrackPlayTile>(
          find.byType(HistoryTrackPlayTile),
        );
        expect([for (final t in tiles) t.row.nth], [3, 2, 1]);
        expect(find.text('#3'), findsOneWidget);
        expect(find.text('listened 1:00'), findsNWidgets(3));
        expect(find.text('Thu, Oct 22 · 9:00 AM'), findsOneWidget);
      },
    );

    historyTestWidgets('from Most played; back keeps the page and the range', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A')],
        plays: [('A', _at(22))],
        page: mostPlayedPath,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '7 days'));
      await settleHistory(tester);

      // The ranking rows have no more button: a long press opens the menu.
      await tester.longPress(find.byType(MostPlayedRowTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Song history'));
      await settleHistory(tester);
      expect(location(h), mostPlayedTrackLocation('/m/A.flac'));
      expect(
        find.text('1 listen · First Thu, Oct 22 · Last Thu, Oct 22 9:00 AM'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Back'));
      await settleHistory(tester);

      expect(location(h), mostPlayedPath);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7 days'))
            .selected,
        isTrue,
      );
      expect(find.byType(MostPlayedRowTile), findsOneWidget);
    });

    historyTestWidgets('the song history page has no Song history item', (
      tester,
    ) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Song history'), findsNothing);
      expect(find.text('Remove from history'), findsOneWidget);
    });

    historyTestWidgets('no path says the song was not found', (tester) async {
      await insertTracks(tester, h, const []);
      await h.pump(tester, hasRoots: true);

      goTo(tester, h, '$historyPath/track');
      await settleHistory(tester);
      expect(find.text('Song not found'), findsOneWidget);

      goTo(tester, h, '$historyPath/track?path=');
      await settleHistory(tester);
      expect(find.text('Song not found'), findsOneWidget);
      expect(_play, findsNothing);
    });
  });

  group('playing', () {
    historyTestWidgets('Play queues the song by its library path', (
      tester,
    ) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      await tester.tap(_play);
      await tester.pump();

      expect(_queue(h), ['/m/A.flac']);
    });

    historyTestWidgets('the row menu queues the song', (tester) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      await _menuOfRow(tester, 0, 'Add to queue');
      expect(_queue(h), ['/m/A.flac']);

      await _menuOfRow(tester, 0, 'Play next');
      expect(_queue(h), ['/m/A.flac', '/m/A.flac']);
    });

    historyTestWidgets('an address that is not a library song cannot play', (
      tester,
    ) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, 'http://x/a.mp3', _at(22));
      await _insert(tester, h, '/m/orphan.flac', _at(21));
      await h.pump(tester, hasRoots: true);

      for (final path in ['http://x/a.mp3', '/m/orphan.flac', '/m/none.flac']) {
        goTo(tester, h, historyTrackLocation(path));
        await settleHistory(tester);
        expect(_play, findsNothing, reason: path);
        expect(find.text('Not in library'), findsOneWidget, reason: path);
      }
      expect(_queue(h), isEmpty);
    });

    historyTestWidgets('a play with no time listened hides it', (tester) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await _insert(tester, h, '/m/A.flac', _at(21), listenedMs: 125000);
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      expect(find.textContaining('listened'), findsOneWidget);
      expect(find.text('listened 2:05'), findsOneWidget);
    });
  });

  group('removing', () {
    historyTestWidgets('removes one play from the menu and Undo restores it', (
      tester,
    ) async {
      await insertTracks(tester, h, [song('A')]);
      final ids = [
        for (final d in [20, 21, 22])
          await _insert(tester, h, '/m/A.flac', _at(d)),
      ];
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      // The middle row is the 21st.
      await _menuOfRow(tester, 1, 'Remove from history');

      expect(await _ids(tester, h), {ids[0], ids[2]});
      expect(find.textContaining('2 listens'), findsOneWidget);
      expect(find.byType(HistoryTrackPlayTile), findsNWidgets(2));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settleHistory(tester);

      expect(await _ids(tester, h), ids.toSet());
      expect(find.textContaining('3 listens'), findsOneWidget);
      expect(find.byType(HistoryTrackPlayTile), findsNWidgets(3));
    });

    historyTestWidgets('removing the last play stays on the page', (
      tester,
    ) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);

      await _menuOfRow(tester, 0, 'Remove from history');

      expect(location(h), historyTrackLocation('/m/A.flac'));
      expect(find.text('No listens yet'), findsOneWidget);
      expect(find.byType(HistoryTrackPlayTile), findsNothing);
      // The song is still in the library, so it still plays.
      expect(_play, findsOneWidget);
    });

    historyTestWidgets('a new play of the song shows up', (tester) async {
      await insertTracks(tester, h, [song('A')]);
      await _insert(tester, h, '/m/A.flac', _at(22));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, historyTrackLocation('/m/A.flac'));
      await settleHistory(tester);
      expect(find.byType(HistoryTrackPlayTile), findsOneWidget);

      await _insert(tester, h, '/m/A.flac', _at(23));
      await settleHistory(tester);

      expect(find.byType(HistoryTrackPlayTile), findsNWidgets(2));
      expect(find.textContaining('2 listens'), findsOneWidget);
    });
  });
}
