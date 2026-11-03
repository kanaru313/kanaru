import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_range.dart';
import 'package:kanaru/features/history/most_played_range.dart';
import 'package:kanaru/shared/m3u/m3u_save_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../playlists/add_to_playlist_test_support.dart';
import '../history_test_harness.dart';
import 'history_day_modal_test_support.dart';

const _day23 = 'Oct 23, 2026 • 3 songs';
const _day22 = 'Oct 22, 2026 • 1 song';

void main() {
  late Directory tmp;
  late LibraryHarness h;
  final suggested = <String>[];
  var savePath = '';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru-day-modal');
    suggested.clear();
    savePath = '${tmp.path}/day.m3u8';
    h = historyHarness(
      overrides: [
        m3uSavePickerProvider.overrideWithValue((name) async {
          suggested.add(name);
          return savePath;
        }),
      ],
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// The 23rd, newest first: gone, A, B, A. The 22nd: Z.
  Future<void> open(WidgetTester tester) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('Z')],
    plays: [
      ('A', at(23, 8)),
      ('B', at(23, 9)),
      ('A', at(23, 10)),
      ('gone', at(23, 11)),
      ('Z', at(22, 11)),
    ],
  );

  group('playing', () {
    historyTestWidgets('Play all queues the songs last played first, once', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);
      await tapRow(tester, 'play-all');

      // Shown newest first as gone, A, B, A: the missing one is skipped and
      // A stays at its first place.
      expect(queueUris(h), ['/m/A.flac', '/m/B.flac']);
      expect(currentUri(h), '/m/A.flac');
    });

    historyTestWidgets('Shuffle queues the same songs', (tester) async {
      await open(tester);
      await openDayModal(tester);
      await tapRow(tester, 'shuffle');

      expect(queueUris(h).toSet(), {'/m/A.flac', '/m/B.flac'});
      expect(queueUris(h), hasLength(2));
    });

    historyTestWidgets('Play next and Add to queue take the same songs', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);
      await tester.tap(find.text('Play next'));
      await settleModal(tester);
      expect(queueUris(h), ['/m/A.flac', '/m/B.flac']);

      await openDayModal(tester);
      await tester.tap(find.text('Add to queue'));
      await settleModal(tester);
      expect(queueUris(h), [
        '/m/A.flac',
        '/m/B.flac',
        '/m/A.flac',
        '/m/B.flac',
      ]);
    });
  });

  group('Add to playlist', () {
    historyTestWidgets('suggests the date and keeps the distinct songs', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);
      await tapRow(tester, 'add-to-playlist');

      await tester.tap(inPicker('New playlist…'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(nameField).controller!.text,
        'Oct 23, 2026',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(pickerAdd);
      await settleHistory(tester);

      final entries = await tester.runAsync(
        () => (h.db.select(
          h.db.playlistEntries,
        )..orderBy([(e) => OrderingTerm.asc(e.position)])).get(),
      );
      expect([for (final e in entries!) e.path], ['/m/A.flac', '/m/B.flac']);
    });
  });

  group('Open in Most played and export', () {
    historyTestWidgets('Open in Most played shows that day as a custom range', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);
      expect(find.text('Oct 23, 2026'), findsNWidgets(2));
      await tapRow(tester, 'open-in-most-played');
      await settleHistory(tester);

      expect(location(h), '/most-played');
      final range = h.container.read(mostPlayedRangeProvider);
      expect(range.preset, HistoryRangePreset.custom);
      expect(range.customStart, DateTime(2026, 10, 23));
      expect(range.customEndInclusive, DateTime(2026, 10, 23));
      // A (2 plays) and B (1) played that day; Z on the 22nd is outside.
      expect(find.text('Z'), findsNothing);
      expect(listText('A'), findsOneWidget);
      expect(listText('B'), findsOneWidget);
    });

    Future<String> export(WidgetTester tester, String row) async {
      await openDayModal(tester);
      await tester.tap(
        row == 'export-relative'
            ? find.descendant(
                of: modalRow('export-m3u'),
                matching: find.byTooltip('Export with relative paths'),
              )
            : modalRow(row),
      );
      for (
        var i = 0;
        i < 40 && find.textContaining('Saved').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      return File(savePath).readAsStringSync();
    }

    historyTestWidgets('both exports list the songs last played first', (
      tester,
    ) async {
      await open(tester);
      final absolute = await export(tester, 'export-m3u');
      expect(suggested, ['Oct 23, 2026.m3u8']);
      final paths = absolute.split('\n').where((l) => l.startsWith('/m/'));
      expect(paths, ['/m/A.flac', '/m/B.flac']);
      expect(find.textContaining('Saved 2 songs to day.m3u8'), findsOneWidget);
    });

    historyTestWidgets('relative paths do not start at the root', (
      tester,
    ) async {
      await open(tester);
      final relative = await export(tester, 'export-relative');
      final lines = relative.split('\n').where((l) => l.contains('.flac'));
      expect(lines, hasLength(2));
      expect(lines.any((l) => l.startsWith('/')), isFalse);
      expect(lines.first, contains('A.flac'));
    });
  });

  group('Remove day', () {
    Future<void> remove(WidgetTester tester) async {
      await tester.tap(modalRow('remove-day'));
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove day from history'),
      );
      await settleHistory(tester);
    }

    historyTestWidgets('asks first; Cancel comes back to the modal', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);
      await remove(tester);

      expect(find.text('Remove this day?'), findsOneWidget);
      expect(
        find.text(
          'All 4 listens of Oct 23, 2026 are removed from History and Most '
          'played. The songs stay in your library.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Play all'), findsOneWidget);
      final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
      expect(left, hasLength(5));
    });

    historyTestWidgets('empties the day; Undo brings it back', (tester) async {
      await open(tester);
      await openDayModal(tester);
      await remove(tester);
      await confirm(tester);

      expect(find.text('Play all'), findsNothing);
      expect(listText(_day23), findsNothing);
      expect(listText(_day22), findsOneWidget);
      expect(find.text('Removed 4 listens from history'), findsOneWidget);
      final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
      expect(left!.map((p) => p.path), ['/m/Z.flac']);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settleHistory(tester);

      expect(listText(_day23), findsOneWidget);
      final back = await tester.runAsync(() => h.db.select(h.db.plays).get());
      expect(back, hasLength(5));
    });

    historyTestWidgets('deletes the plays shown, not one recorded since', (
      tester,
    ) async {
      await open(tester);
      await openDayModal(tester);

      await seedPlays(tester, h, [('B', at(23, 11))]);
      await remove(tester);
      await confirm(tester);

      final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
      expect(left!.map((p) => p.path).toSet(), {'/m/Z.flac', '/m/B.flac'});
      expect(left, hasLength(2));
    });

    historyTestWidgets('spares a play held back while scrolled away', (
      tester,
    ) async {
      await openHistory(
        tester,
        h,
        tracks: [for (var i = 0; i < 30; i++) song('S$i'), song('New')],
        plays: [for (var i = 0; i < 30; i++) ('S$i', at(23, 0))],
      );
      await scrollTimelineTo(tester, lineExtentOf(tester) * 6);
      await seedPlays(tester, h, [('New', at(23, 11))]);
      await settleHistory(tester);

      await rightClick(tester, pinnedBar);
      await remove(tester);
      await confirm(tester);

      // The page showed 30 plays: the one it held back is not deleted.
      final left = await tester.runAsync(() => h.db.select(h.db.plays).get());
      expect(left!.map((p) => p.path), ['/m/New.flac']);
    });

    historyTestWidgets('removing the only day of an older year falls back to '
        'the newest year; Undo brings the year back', (tester) async {
      await openHistory(
        tester,
        h,
        tracks: [song('A'), song('B')],
        plays: [('A', at(23, 9)), ('B', at(31, 9, 12, 2025))],
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
      await settleHistory(tester);
      expect(find.text('B'), findsOneWidget);

      await openDayModal(tester);
      await remove(tester);
      await confirm(tester);
      // The year has no plays: the page falls back to the newest year.
      expect(find.text('A'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await settleHistory(tester);
      expect(find.widgetWithText(ChoiceChip, '2025'), findsOneWidget);
      expect(timelineOffset(tester), 0);
    });
  });
}
