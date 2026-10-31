import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_calendar_style.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/history_range_bar.dart';
import 'package:kanaru/features/history/most_played_actions.dart';
import 'package:kanaru/features/history/most_played_list.dart';
import 'package:kanaru/features/history/most_played_row_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
import '../../shared/song_modal/song_modal_test_support.dart';
import 'history_test_harness.dart';

DateTime _at(int month, int day, [int hour = 9]) =>
    DateTime(2026, month, day, hour);

/// Shared by the top queries of the range and the all-time branch.
const _topSql = 'ORDER BY a.n DESC';

/// B and A tie on 3 plays inside the last 30 days, B's last one earlier.
/// Ghost is not in the library. D is only in the full history.
final _plays = <SeedPlay>[
  for (final d in [20, 21, 22]) ('A', _at(10, d)),
  for (final d in [10, 11, 12]) ('B', _at(10, d)),
  ('C', _at(10, 22, 10)),
  ('Ghost', _at(10, 15)),
  ('Ghost', _at(10, 15, 10)),
  for (var i = 0; i < 5; i++) ('D', _at(2, 1, 8 + i)),
];

final _tracks = [song('A'), song('B'), song('C'), song('D')];

Future<void> _openTop(
  WidgetTester tester,
  LibraryHarness h, {
  List<SeedPlay>? plays,
  GatedQueryInterceptor? gate,
}) async {
  await openHistory(
    tester,
    h,
    tracks: _tracks,
    plays: plays ?? _plays,
    gate: gate,
    page: mostPlayedPath,
  );
}

/// Taps a range chip; the bar scrolls sideways in the narrower right column,
/// so the chip may first have to be brought into view.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
}

Future<void> _chip(WidgetTester tester, String label) async {
  await _tapChip(tester, label);
  await settleHistory(tester);
}

/// File names of the rows on show, in order, without the extension.
List<String> _names(WidgetTester tester) => [
  for (final t in tester.widgetList<MostPlayedRowTile>(
    find.byType(MostPlayedRowTile),
  ))
    t.row.path.split('/').last.replaceAll('.flac', ''),
];

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

bool _enabled(WidgetTester tester, Finder button) {
  final w = tester.widget<ButtonStyleButton>(button);
  return w.onPressed != null;
}

Finder get _playAll => find.widgetWithText(FilledButton, 'Play');

/// The page's more menu (next to Play and Shuffle), opened.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

Finder get _create =>
    find.widgetWithText(PopupMenuItem<MostPlayedChoice>, 'Create playlist');

/// Whether the menu item behind [item] can be picked.
bool _itemEnabled(WidgetTester tester, Finder item) =>
    tester.widget<PopupMenuItem<MostPlayedChoice>>(item).enabled;

/// Opens the menu of a row the way a pointer does: a long press on it.
Future<void> _rowMenu(WidgetTester tester, int index) async {
  await tester.longPress(find.byType(MostPlayedRowTile).at(index));
  await settleSongModal(tester);
}

/// Picks the days [from] to [to] of October 2026 in the range dialog.
Future<void> _pickDays(WidgetTester tester, int from, int to) async {
  for (final day in [from, to]) {
    await tester.tap(find.byKey(historyDayCellKey(DateTime(2026, 10, day))));
    await tester.pump();
  }
  await tester.tap(find.text('Save'));
  await settleHistory(tester);
}

void main() {
  late LibraryHarness h;

  setUp(() => h = historyHarness());

  group('cap', () {
    Future<void> openWith(WidgetTester tester, int songs) async {
      await openHistory(
        tester,
        h,
        plays: [for (var i = 0; i < songs; i++) ('g$i', _at(10, 22, i % 24))],
        page: mostPlayedPath,
      );
    }

    historyTestWidgets('exactly the limit shows no note', (tester) async {
      await openWith(tester, 500);
      await tester.drag(find.byType(MostPlayedList), const Offset(0, -100000));
      await tester.pumpAndSettle();

      expect(find.byType(MostPlayedRowTile).last, findsOneWidget);
      expect(find.text('Showing first 500'), findsNothing);
    });

    historyTestWidgets('one more than the limit shows the note', (
      tester,
    ) async {
      await openWith(tester, 501);

      // The line is the last of the list.
      await tester.drag(find.byType(MostPlayedList), const Offset(0, -100000));
      await tester.pumpAndSettle();
      expect(find.text('Showing first 500'), findsOneWidget);
    });
  });

  group('ranking', () {
    historyTestWidgets(
      'starts at 30 days, ties broken by the earlier last play',
      (tester) async {
        await _openTop(tester, h);

        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '30 days'))
              .selected,
          isTrue,
        );
        // D is older than 30 days. B and A tie on 3: B played last earlier.
        expect(_names(tester), ['B', 'A', 'Ghost', 'C']);
        expect(find.text('3 listens'), findsNWidgets(2));
        expect(find.text('1 listen'), findsOneWidget);
      },
    );

    historyTestWidgets('a preset changes the list, today may have nothing', (
      tester,
    ) async {
      await _openTop(tester, h);

      await _chip(tester, '7 days');
      expect(_names(tester), ['A', 'C']);

      await _chip(tester, 'Today');
      expect(_names(tester), isEmpty);
      expect(find.text('No listens in this range'), findsOneWidget);
      expect(_enabled(tester, _playAll), isFalse);
      await _openMenu(tester);
      expect(_itemEnabled(tester, _create), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    historyTestWidgets(
      'previous shows that period, next is off on the current',
      (tester) async {
        await _openTop(tester, h);
        await _chip(tester, '7 days');

        IconButton next() => tester.widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Next period',
          ),
        );
        expect(next().onPressed, isNull);

        await tester.tap(find.byTooltip('Previous period'));
        await settleHistory(tester);
        expect(_names(tester), ['B', 'Ghost']);
        expect(next().onPressed, isNotNull);

        await tester.tap(find.byTooltip('Next period'));
        await settleHistory(tester);
        expect(_names(tester), ['A', 'C']);
        expect(next().onPressed, isNull);
      },
    );

    historyTestWidgets(
      'all time reads the whole history, as does a long range',
      (tester) async {
        final gate = GatedQueryInterceptor();
        h = historyHarness(interceptor: gate);
        await _openTop(tester, h, gate: gate);

        await _chip(tester, 'All time');
        expect(_names(tester), ['D', 'B', 'A', 'Ghost', 'C']);
        expect(find.byTooltip('Previous period'), findsNothing);

        // The year takes in every play: the same list from the all-time query.
        final before = gate.count('FROM play_stats');
        await _chip(tester, '1 year');
        expect(_names(tester), ['D', 'B', 'A', 'Ghost', 'C']);
        expect(gate.count('FROM play_stats'), before);
      },
    );

    historyTestWidgets(
      'a range shorter than the history reads only its plays',
      (tester) async {
        final gate = GatedQueryInterceptor();
        h = historyHarness(interceptor: gate);
        await _openTop(tester, h, gate: gate);

        expect(gate.count('FROM play_stats'), 0);
        expect(gate.count('FROM plays'), greaterThan(0));
      },
    );
  });

  group('custom range', () {
    historyTestWidgets('picks days in the picker, then steps by its length', (
      tester,
    ) async {
      await _openTop(tester, h);

      await _tapChip(tester, 'Custom');
      await settleHistory(tester);
      await _pickDays(tester, 10, 12);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Custom'))
            .selected,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(HistoryRangeBar),
          matching: find.textContaining(' – '),
        ),
        findsOneWidget,
      );
      expect(_names(tester), ['B']);

      // Oct 7 to Oct 9 has no plays, Oct 13 to Oct 15 has the Ghost's two.
      await tester.tap(find.byTooltip('Previous period'));
      await settleHistory(tester);
      expect(_names(tester), isEmpty);
      await tester.tap(find.byTooltip('Next period'));
      await tester.tap(find.byTooltip('Next period'));
      await settleHistory(tester);
      expect(_names(tester), ['Ghost']);
    });

    historyTestWidgets(
      'opens with no assert from a long preset, and again later',
      (tester) async {
        // Two months of plays while the preset is one year.
        await _openTop(
          tester,
          h,
          plays: [('A', _at(8, 20)), ('B', _at(10, 1))],
        );
        await _chip(tester, '1 year');

        await _tapChip(tester, 'Custom');
        await settleHistory(tester);
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleHistory(tester);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1 year'))
              .selected,
          isTrue,
        );

        await _tapChip(tester, 'Custom');
        await settleHistory(tester);
        await _pickDays(tester, 1, 5);
        await _tapChip(tester, 'Custom');
        await settleHistory(tester);
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    historyTestWidgets('the Custom chip is off while nothing was played', (
      tester,
    ) async {
      await _openTop(tester, h, plays: const []);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Custom'))
            .onSelected,
        isNull,
      );
      expect(find.text('No listens in this range'), findsOneWidget);
    });
  });

  group('playing', () {
    historyTestWidgets(
      'a tap queues the songs that can play, from the tapped',
      (tester) async {
        await _openTop(tester, h);

        // Rows B, A, Ghost, C: the Ghost is left out, C is third in the queue.
        await tester.tap(find.byType(MostPlayedRowTile).at(3));
        await tester.pump();

        expect(_queue(h), ['/m/B.flac', '/m/A.flac', '/m/C.flac']);
        expect(
          h.container.read(playerServiceProvider).queue.current?.uri,
          '/m/C.flac',
        );
      },
    );

    historyTestWidgets(
      'a song gone from the library is dimmed and does not play',
      (tester) async {
        await _openTop(tester, h);

        expect(find.text('Not in library'), findsOneWidget);
        await tester.tap(find.byType(MostPlayedRowTile).at(2));
        await tester.pump();
        expect(_queue(h), isEmpty);
      },
    );

    historyTestWidgets('Play all queues the playable songs by rank', (
      tester,
    ) async {
      await _openTop(tester, h);

      await tester.tap(_playAll);
      await tester.pump();

      expect(_queue(h), ['/m/B.flac', '/m/A.flac', '/m/C.flac']);
      expect(
        h.container.read(playerServiceProvider).queue.current?.uri,
        '/m/B.flac',
      );
    });

    historyTestWidgets('the buttons are off when no song can play', (
      tester,
    ) async {
      await _openTop(tester, h, plays: [('Ghost', _at(10, 15))]);

      expect(_names(tester), ['Ghost']);
      expect(_enabled(tester, _playAll), isFalse);
      await _openMenu(tester);
      expect(_itemEnabled(tester, _create), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    historyTestWidgets('the row modal has Song history and no remove item', (
      tester,
    ) async {
      await _openTop(tester, h);

      await _rowMenu(tester, 0);

      expect(find.bySemanticsLabel('Song options'), findsWidgets);
      expect(find.text('Play next'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Song history'), findsOneWidget);
      expect(find.text('Remove from history'), findsNothing);
      // B was played 3 times: the header says so, as the row badge does.
      expect(find.text('3 listens'), findsWidgets);
    });

    historyTestWidgets('every way to open the row modal works', (tester) async {
      await _openTop(tester, h);
      final row = find.byType(MostPlayedRowTile).first;

      await tester.tap(row, buttons: kSecondaryButton);
      await settleSongModal(tester);
      expect(find.text('Song history'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleSongModal(tester);

      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('More options')),
      );
      await settleSongModal(tester);
      expect(find.text('Song history'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleSongModal(tester);

      for (final shift in [false, true]) {
        final ink = find.descendant(of: row, matching: find.byType(InkWell));
        final inside = find.descendant(
          of: find
              .descendant(of: ink.first, matching: find.byType(Focus))
              .first,
          matching: find.byType(Semantics),
        );
        Focus.of(tester.element(inside.first)).requestFocus();
        await tester.pump();
        if (shift) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.sendKeyEvent(
          shift ? LogicalKeyboardKey.f10 : LogicalKeyboardKey.contextMenu,
        );
        if (shift) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        await settleSongModal(tester);
        expect(find.text('Song history'), findsOneWidget, reason: '$shift');
        expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleSongModal(tester);
      }
    });

    historyTestWidgets('a narrow row with rank, a large count, heart and more '
        'button does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _openTop(
        tester,
        h,
        plays: [
          for (var i = 0; i < 1234; i++)
            ('A', _at(10, 20, 1).add(Duration(seconds: i))),
        ],
      );

      expect(find.text('1234 listens'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    historyTestWidgets('Song history in the modal opens the song page', (
      tester,
    ) async {
      await _openTop(tester, h);
      await _rowMenu(tester, 0);

      await tester.tap(find.text('Song history'));
      await settleSongModal(tester);

      expect(location(h), mostPlayedTrackLocation('/m/B.flac'));
    });

    historyTestWidgets('Add to queue in the modal queues the row song', (
      tester,
    ) async {
      await _openTop(tester, h);
      await _rowMenu(tester, 0);

      await tester.tap(find.text('Add to queue'));
      await settleSongModal(tester);

      expect(_queue(h), ['/m/B.flac']);
    });

    historyTestWidgets('a song gone from the library keeps the small menu', (
      tester,
    ) async {
      await _openTop(tester, h, plays: [('Ghost', _at(10, 15))]);

      expect(find.byTooltip('More options'), findsNothing);
      await tester.tap(find.text('Ghost.flac'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsWidgets);
      expect(find.bySemanticsLabel('Song options'), findsNothing);
      expect(find.text('Remove from history'), findsNothing);
    });
  });

  group('create playlist', () {
    Future<List<String>> entries(WidgetTester tester) async {
      final rows = await tester.runAsync(() async {
        return (h.db.select(
          h.db.playlistEntries,
        )..orderBy([(e) => OrderingTerm.asc(e.position)])).get();
      });
      return [for (final e in rows!) e.path];
    }

    historyTestWidgets('names it after the range and keeps the rank order', (
      tester,
    ) async {
      await _openTop(tester, h);
      await _chip(tester, '7 days');
      await tester.tap(find.byTooltip('Previous period'));
      await settleHistory(tester);

      await _openMenu(tester);
      await tester.tap(_create);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, startsWith('Most played · '));
      final name = field.controller!.text;

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleHistory(tester);

      // B and the Ghost: only the library song goes in.
      expect(await entries(tester), ['/m/B.flac']);
      expect(find.text('Created playlist $name'), findsOneWidget);
    });

    historyTestWidgets('keeps every playable song in rank order', (
      tester,
    ) async {
      await _openTop(tester, h);

      await _openMenu(tester);
      await tester.tap(_create);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleHistory(tester);

      expect(await entries(tester), ['/m/B.flac', '/m/A.flac', '/m/C.flac']);
    });

    historyTestWidgets('cancelling writes nothing', (tester) async {
      await _openTop(tester, h);

      await _openMenu(tester);
      await tester.tap(_create);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await settleHistory(tester);

      expect(await entries(tester), isEmpty);
      final playlists = await tester.runAsync(
        () => h.db.select(h.db.playlists).get(),
      );
      expect(playlists, isEmpty);
      expect(find.textContaining('Created playlist'), findsNothing);
    });
  });

  group('page and reloading', () {
    historyTestWidgets('keeps the range when another page is shown and back', (
      tester,
    ) async {
      await _openTop(tester, h);
      await _chip(tester, '7 days');

      goTo(tester, h, historyPath);
      await settleHistory(tester);
      goTo(tester, h, mostPlayedPath);
      await settleHistory(tester);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7 days'))
            .selected,
        isTrue,
      );
      expect(_names(tester), ['A', 'C']);
    });

    historyTestWidgets(
      'Most played in a hidden branch does not read new plays',
      (tester) async {
        final gate = GatedQueryInterceptor();
        h = historyHarness(interceptor: gate);
        await _openTop(tester, h, gate: gate);
        goTo(tester, h, historyPath);
        await settleHistory(tester);
        final before = gate.count(_topSql);
        expect(before, greaterThan(0));

        await seedPlays(tester, h, [('C', _at(10, 23, 11))]);
        await settleHistory(tester);
        expect(gate.count(_topSql), before);

        // Shown again, it catches up.
        goTo(tester, h, mostPlayedPath);
        await settleHistory(tester);
        expect(gate.count(_topSql), greaterThan(before));
        expect(find.text('2 listens'), findsNWidgets(2));
      },
    );

    historyTestWidgets('a new play updates the list in place', (tester) async {
      await _openTop(tester, h);
      expect(_names(tester).last, 'C');

      await seedPlays(tester, h, [
        ('C', _at(10, 23, 11)),
        ('C', _at(10, 23, 11)),
        ('C', _at(10, 23, 11)),
      ]);
      await settleHistory(tester);

      expect(_names(tester).first, 'C');
    });

    historyTestWidgets(
      'a range being read keeps the old list under a thin bar',
      (tester) async {
        final gate = GatedQueryInterceptor();
        h = historyHarness(interceptor: gate);
        await _openTop(tester, h, gate: gate);
        expect(find.byType(LinearProgressIndicator), findsNothing);

        final release = gate.holdNext(_topSql);
        await _tapChip(tester, '7 days');
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();

        expect(_names(tester), ['B', 'A', 'Ghost', 'C']);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('No listens in this range'), findsNothing);

        release();
        await settleHistory(tester);
        expect(_names(tester), ['A', 'C']);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
