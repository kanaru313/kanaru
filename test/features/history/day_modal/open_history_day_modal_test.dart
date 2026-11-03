import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/day_modal/open_history_day_modal.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/features/history/history_timeline_body.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../history_test_harness.dart';
import 'history_day_modal_test_support.dart';

Finder get _modal => find.text('Play all');

bool _focusIn(Finder within) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: within,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  late LibraryHarness h;

  setUp(() {
    h = historyHarness();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  /// The 23rd (today): gone (newest), A, B, A. The 22nd: Z. The 20th: Z.
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
      ('Z', at(20, 11)),
    ],
  );

  historyTestWidgets('a right click on a day bar opens the Day modal', (
    tester,
  ) async {
    await open(tester);
    await openDayModal(tester);

    expect(_modal, findsOneWidget);
    for (final label in [
      'Play all',
      'Shuffle',
      'Add to playlist…',
      'Open in Most played',
      'Export as M3U',
      'Remove day from history',
      'Play next',
      'Add to queue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('2 songs, last played first'), findsOneWidget);
    expect(find.text('New playlist suggests “Oct 23, 2026”'), findsOneWidget);
    expect(find.text('4 listens · songs stay in your library'), findsOneWidget);
  });

  historyTestWidgets('the header names the day and counts its plays', (
    tester,
  ) async {
    await open(tester);
    await openDayModal(tester);

    expect(find.text('Today'), findsOneWidget);
    // The date is in the header and in the Open in Most played row.
    expect(find.text('Oct 23, 2026'), findsNWidgets(2));
    expect(find.text('4 listens • 3 songs • listened 4 min'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ContextModalHeader),
        matching: find.byIcon(AppIcons.calendar),
      ),
      findsOneWidget,
    );
  });

  historyTestWidgets('yesterday and an older day are named', (tester) async {
    await open(tester);
    await openDayModal(tester, 1);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Oct 22, 2026'), findsNWidgets(2));
    expect(find.text('1 listen • 1 song • listened 1 min'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);

    await openDayModal(tester, 2);
    // October 20, 2026 was a Tuesday.
    expect(find.text('Tuesday'), findsOneWidget);
  });

  historyTestWidgets('a long press and the ⋮ button open it too', (
    tester,
  ) async {
    await open(tester);
    await tester.longPress(dayBar());
    await settleModal(tester);
    expect(_modal, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);
    expect(_modal, findsNothing);

    await tester.tap(dayMore());
    await settleModal(tester);
    expect(_modal, findsOneWidget);
  });

  historyTestWidgets('the ⋮ button still says which day it is for', (
    tester,
  ) async {
    await open(tester);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('Day options, Oct 23, 2026')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    historyTestWidgets(
      '${key.keyLabel} on the ⋮ button focuses the first row',
      (tester) async {
        await open(tester);
        Focus.of(tester.element(find.byIcon(AppIcons.moreHoriz).first))
            .requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(key);
        await settleModal(tester);

        expect(_modal, findsOneWidget);
        expect(_focusIn(modalRow('play-all')), isTrue);
      },
    );
  }

  for (final (name, shift, key) in [
    ('the Menu key', false, LogicalKeyboardKey.contextMenu),
    ('Shift+F10', true, LogicalKeyboardKey.f10),
  ]) {
    historyTestWidgets('$name on the ⋮ button opens it', (tester) async {
      await open(tester);
      Focus.of(tester.element(find.byIcon(AppIcons.moreHoriz).first))
          .requestFocus();
      await tester.pump();
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleModal(tester);

      expect(_modal, findsOneWidget);
      expect(_focusIn(modalRow('play-all')), isTrue);
    });
  }

  historyTestWidgets('the pinned bar opens the modal with a right click', (
    tester,
  ) async {
    await openHistory(
      tester,
      h,
      tracks: [for (var i = 0; i < 12; i++) song('S$i')],
      plays: [for (var i = 0; i < 12; i++) ('S$i', at(23, i))],
    );
    await scrollTimelineTo(tester, lineExtentOf(tester) * 5);

    await rightClick(tester, pinnedBar);
    await tapRow(tester, 'play-all');

    expect(queueUris(h), [for (var i = 11; i >= 0; i--) '/m/S$i.flac']);
  });

  historyTestWidgets('a double click on the day button opens one modal', (
    tester,
  ) async {
    await open(tester);
    final button = tester.getCenter(dayMore());
    await tester.tapAt(button);
    await tester.tapAt(button);
    await settleModal(tester);

    expect(find.text('Play all'), findsOneWidget);
  });

  historyTestWidgets('a day of songs gone from the library keeps only Remove', (
    tester,
  ) async {
    await openHistory(tester, h, plays: [('gone', at(23, 9))]);
    await openDayModal(tester);

    for (final id in ['play-all', 'shuffle', 'add-to-playlist']) {
      expect(rowEnabled(tester, id), isFalse, reason: id);
    }
    expect(rowEnabled(tester, 'remove-day'), isTrue);
    expect(find.text('1 listen • 1 song • listened 1 min'), findsOneWidget);
  });

  historyTestWidgets('a branch switched during the read gets no modal', (
    tester,
  ) async {
    await open(tester);
    final state = tester.state<ConsumerState<HistoryTimelineBody>>(
      find.byType(HistoryTimelineBody),
    );
    final done = Completer<List<HistoryPlayRow>>();
    unawaited(
      openHistoryDayModal(
        state.ref,
        state.context,
        day: DateTime(2026, 10, 23),
        readDay: () => done.future,
      ),
    );
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    done.complete(const []);
    await settleModal(tester);

    expect(find.text('Play all'), findsNothing);
    expect(find.byType(HistoryPlayRowTile), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    historyTestWidgets('rows and bars fit their lines at text scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await open(tester);

      expect(tester.takeException(), isNull);
      final line = lineExtentOf(tester);
      for (final tile in tester.widgetList(find.byType(HistoryPlayRowTile))) {
        expect(tester.getSize(find.byWidget(tile)).height, line);
      }
      expect(tester.getSize(dayBar()).height, barHeightOf(tester));
    });
  }
}
