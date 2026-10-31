import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/history/history_delete_undo.dart';
import 'package:kanaru/features/history/history_plays_version.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_screen.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../playlists/playlist_test_data.dart' show breakWrites;
import '../../shared/song_modal/song_modal_test_support.dart';
import 'history_test_harness.dart';

const _removed = 'Removed one listen from history';
const _removedTwo = 'Removed 2 listens from history';

DateTime _at(int hour) => DateTime(2026, 10, 23, hour);

/// Removes the play of the song titled [title] through its row menu and
/// lets the page catch up.
Future<void> _remove(WidgetTester tester, String title) async {
  final row = find.ancestor(
    of: find.text(title),
    matching: find.byType(HistoryPlayRowTile),
  );
  await tester.tap(row, buttons: kSecondaryButton);
  await settleSongModal(tester);
  await tester.tap(find.text('Remove from history'));
  await settleSongModal(tester);
  await settleHistory(tester);
}

Future<void> _pressUndo(WidgetTester tester) async {
  await tester.tap(find.text('Undo'));
  await tester.pumpAndSettle();
  await settleHistory(tester);
}

/// `play_stats` against `GROUP BY` over `plays`, as the invariant says.
Future<void> _expectStatsMatch(WidgetTester tester, LibraryHarness h) async {
  final rows = await tester.runAsync(() async {
    Future<List<Map<String, Object?>>> read(String sql) async => [
      for (final r in await h.db.customSelect(sql).get()) r.data,
    ];
    return (
      await read(
        'SELECT path, play_count, first_played_at, last_played_at '
        'FROM play_stats ORDER BY path',
      ),
      await read(
        'SELECT path, count(*) AS play_count, min(played_at) AS '
        'first_played_at, max(played_at) AS last_played_at '
        'FROM plays GROUP BY path ORDER BY path',
      ),
    );
  });
  expect(rows!.$1, rows.$2);
}

Future<Set<int>> _ids(WidgetTester tester, LibraryHarness h) async {
  final rows = await tester.runAsync(() => h.db.select(h.db.plays).get());
  return {for (final Play p in rows!) p.id};
}

ScaffoldMessengerState _messenger(WidgetTester tester) =>
    ScaffoldMessenger.of(tester.element(find.byType(HistoryScreen)));

void main() {
  late LibraryHarness h;
  late List<int> ids;

  setUp(() => h = historyHarness());

  Future<void> open(WidgetTester tester) async {
    await insertTracks(tester, h, [song('A'), song('B'), song('C')]);
    ids = await seedPlays(tester, h, [
      ('A', _at(8)),
      ('B', _at(9)),
      ('A', _at(10)),
      ('C', _at(11)),
    ]);
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/history');
    await settleHistory(tester);
  }

  historyTestWidgets('removing a play drops its row and offers Undo for 4 s', (
    tester,
  ) async {
    await open(tester);

    await _remove(tester, 'B');

    expect(find.text('B'), findsNothing);
    expect(listText('Oct 23, 2026 • 3 songs'), findsNothing);
    expect(listText('Oct 23, 2026 • 2 songs'), findsOneWidget);
    expect(find.text(_removed), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await _expectStatsMatch(tester, h);

    // Not persistent: it closes by itself after its time.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_removed), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(_removed), findsNothing);
  });

  historyTestWidgets('Undo puts the same play back, statistics intact', (
    tester,
  ) async {
    await open(tester);
    await _remove(tester, 'B');

    await _pressUndo(tester);

    expect(find.text('B'), findsOneWidget);
    expect(listText('Oct 23, 2026 • 3 songs'), findsOneWidget);
    expect(await _ids(tester, h), ids.toSet());
    await _expectStatsMatch(tester, h);
    // Pressed once: the snackbar is gone.
    expect(find.text(_removed), findsNothing);
  });

  historyTestWidgets(
    'a second removal replaces the snackbar; Undo restores both',
    (tester) async {
      await open(tester);
      await _remove(tester, 'B');

      await _remove(tester, 'C');
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);
      expect(find.text(_removedTwo), findsOneWidget);
      await _pressUndo(tester);

      expect(find.text('C'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(await _ids(tester, h), ids.toSet());
      await _expectStatsMatch(tester, h);
    },
  );

  historyTestWidgets(
    'removing several plays at once shows the count; Undo restores '
    'them all',
    (tester) async {
      await open(tester);
      final element = tester.element(find.byType(HistoryScreen));
      final container = ProviderScope.containerOf(element);
      await tester.runAsync(
        () => container
            .read(historyDeleteUndoProvider)
            .deleteMany(
              db: h.db,
              messenger: ScaffoldMessenger.of(element),
              l10n: element.l10n,
              version: container.read(historyPlaysVersionProvider.notifier),
              playIds: [ids[0], ids[1], ids[3]],
            ),
      );
      await tester.pumpAndSettle();
      await settleHistory(tester);

      expect(find.text('Removed 3 listens from history'), findsOneWidget);
      expect(await _ids(tester, h), {ids[2]});

      await _pressUndo(tester);

      expect(await _ids(tester, h), ids.toSet());
      await _expectStatsMatch(tester, h);
    },
  );

  historyTestWidgets(
    'removals on pages of different years share one snackbar',
    (tester) async {
      await insertTracks(tester, h, [song('A'), song('B'), song('C')]);
      ids = await seedPlays(tester, h, [
        ('A', DateTime(2026, 10, 23, 8)),
        ('B', DateTime(2025, 6, 1, 9)),
        ('C', DateTime(2025, 6, 1, 10)),
      ]);
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, '/history');
      await settleHistory(tester);

      // The last play of 2026 goes: the page moves on to 2025's body.
      await _remove(tester, 'A');
      await _remove(tester, 'B');
      await tester.pumpAndSettle();

      // One Undo, and it restores both removals.
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text(_removedTwo), findsOneWidget);
      await _pressUndo(tester);
      expect(await _ids(tester, h), ids.toSet());
      await _expectStatsMatch(tester, h);
    },
  );

  historyTestWidgets(
    'a removal while the snackbar leaves after Undo starts afresh',
    (tester) async {
      await open(tester);
      await _remove(tester, 'B');

      // Undo restores B; the snackbar is still animating out when C goes.
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryScreen)),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(HistoryScreen)),
      );
      final cPlay = ids.last;
      await tester.runAsync(
        () => container
            .read(historyDeleteUndoProvider)
            .deleteMany(
              db: h.db,
              messenger: _messenger(tester),
              l10n: l10n,
              version: container.read(historyPlaysVersionProvider.notifier),
              playIds: [cPlay],
            ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_removed), findsOneWidget);
      expect(find.text(_removedTwo), findsNothing);
    },
  );

  historyTestWidgets('another message on screen is never closed', (
    tester,
  ) async {
    await open(tester);
    _messenger(tester).showSnackBar(
      const SnackBar(
        content: Text('Scan finished'),
        duration: Duration(minutes: 10),
      ),
    );
    await tester.pumpAndSettle();

    await _remove(tester, 'B');
    await _remove(tester, 'C');

    // Ours waits behind the scan message, which stays; nothing was asserted.
    expect(tester.takeException(), isNull);
    expect(find.text('Scan finished'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    _messenger(tester).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    expect(find.text('Scan finished'), findsNothing);
    // One Undo for both removals, and the title counts both.
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text(_removedTwo), findsOneWidget);
    await _pressUndo(tester);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  historyTestWidgets('Undo still works after the page is left', (tester) async {
    await open(tester);
    await _remove(tester, 'B');

    goTo(tester, h, '/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    expect(await _ids(tester, h), ids.toSet());
    await _expectStatsMatch(tester, h);
  });

  group('failures', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = [];
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(logs.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = level;
      });
    });

    void expectNoPathInLogs() {
      for (final r in logs) {
        expect(r.message, isNot(contains('/m/')));
        expect(r.message, isNot(contains('disk full')));
        expect(r.error?.toString() ?? '', isNot(contains('/m/')));
      }
    }

    historyTestWidgets('a failed removal says so and keeps the row', (
      tester,
    ) async {
      await open(tester);
      await breakWrites(tester, h, 'plays', 'DELETE');

      await _remove(tester, 'B');

      expect(
        find.text("Couldn't remove the listen. See the log for details."),
        findsOneWidget,
      );
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(
        logs.where((r) => r.message.contains('SqliteException')),
        isNotEmpty,
      );
      expectNoPathInLogs();
    });

    historyTestWidgets('a failed Undo says so', (tester) async {
      await open(tester);
      await _remove(tester, 'B');
      await breakWrites(tester, h, 'plays', 'INSERT');

      await _pressUndo(tester);

      expect(
        find.text("Couldn't restore the listen. See the log for details."),
        findsOneWidget,
      );
      expect(find.text('B'), findsNothing);
      expectNoPathInLogs();
    });
  });
}
