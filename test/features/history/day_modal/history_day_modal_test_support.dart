import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_timeline_view.dart';
import 'package:kanaru/features/history/history_day_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/settle_modal.dart';
import '../history_test_harness.dart';

export '../../../support/settle_modal.dart' show settleModal;

DateTime at(int day, int hour, [int month = 10, int year = 2026]) =>
    DateTime(year, month, day, hour);

List<String> queueUris(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

String? currentUri(LibraryHarness h) =>
    h.container.read(playerServiceProvider).queue.current?.uri;

/// The row of the open Day modal with action [id].
Finder modalRow(String id) => find.byKey(ValueKey('context-modal-action-$id'));

/// The bar of the day at [index] in the list (0 is the newest).
Finder dayBar([int index = 0]) => find.byType(HistoryDayBar).at(index);

/// The ⋮ button of the bar at [index].
Finder dayMore([int index = 0]) =>
    find.descendant(of: dayBar(index), matching: find.byType(IconButton));

/// The copy of a bar pinned at the top of the list.
Finder get pinnedBar => find.descendant(
  of: find.byKey(historyStickyHeaderKey),
  matching: find.byType(HistoryDayBar),
);

/// Right clicks [bar] and waits for the modal.
Future<void> rightClick(WidgetTester tester, Finder bar) async {
  await tester.tap(bar, buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Opens the Day modal of the newest day with a right click.
Future<void> openDayModal(WidgetTester tester, [int index = 0]) =>
    rightClick(tester, dayBar(index));

/// Taps the modal row [id] and waits for what it starts.
Future<void> tapRow(WidgetTester tester, String id) async {
  await tester.tap(modalRow(id));
  await settleModal(tester);
}

/// Whether the modal row [id] reacts to a tap.
bool rowEnabled(WidgetTester tester, String id) =>
    tester
        .widget<InkWell>(
          find
              .descendant(of: modalRow(id), matching: find.byType(InkWell))
              .first,
        )
        .onTap !=
    null;
