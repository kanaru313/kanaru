import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/stats/listen_recorder_provider.dart';
import 'package:kanaru/features/history/history_clock.dart';
import 'package:kanaru/features/history/history_side_pane.dart';
import 'package:kanaru/shared/icons/app_icons.dart';

import '../../../core/stats/gated_query_interceptor.dart';
import '../../../support/settle_modal.dart';
import '../../playlists/playlist_test_data.dart' show breakWrites;
import '../history_test_harness.dart';

DateTime _at(int day, int hour) => DateTime(2026, 10, day, hour);

Finder _row(String id) => find.byKey(ValueKey('context-modal-action-$id'));
Finder _option(String name) => find.byKey(ValueKey('history-clear-$name'));
final _confirm = find.byKey(const ValueKey('history-clear-confirm'));
final _more = find.descendant(
  of: find.byType(HistorySidePane),
  matching: find.byIcon(AppIcons.more),
);

void main() {
  // The History clock is 23 Oct 2026, 12:00. Plays: 20th, 21st, 22nd 9:00 and
  // today 9:00 (so last hour holds none).
  late LibraryHarness h;
  var clock = historyTestNow;
  late GatedQueryInterceptor gate;

  setUp(() {
    clock = historyTestNow;
    gate = GatedQueryInterceptor();
    // Not historyHarness: the clock must move during a test.
    h = LibraryHarness(
      interceptor: gate,
      overrides: [historyNowProvider.overrideWithValue(() => clock)],
    );
  });

  Future<void> open(WidgetTester tester) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('Z')],
    plays: [
      ('gone', _at(20, 9)),
      ('Z', _at(21, 9)),
      ('A', _at(22, 9)),
      ('B', _at(23, 9)),
    ],
  );

  /// Modal, Advanced, Clear history…: the dialog is open.
  Future<void> openDialog(WidgetTester tester) async {
    await open(tester);
    await tester.tap(_more);
    await settleModal(tester);
    await tester.tap(_row('advanced'));
    await settleModal(tester);
    await tester.tap(_row('clear'));
    await settleModal(tester);
  }

  bool confirmEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(_confirm).onPressed != null;

  Future<int> playCount(WidgetTester tester) async =>
      (await tester.runAsync(() => h.db.select(h.db.plays).get()))!.length;

  historyTestWidgets('lists four ranges with their counts', (tester) async {
    await openDialog(tester);

    expect(find.text('Clear history?'), findsOneWidget);
    expect(find.textContaining("This can't be undone."), findsOneWidget);
    for (final (name, label, count) in [
      ('lastHour', 'Last hour', '0 listens'),
      ('today', 'Today', '1 listen'),
      ('days7', 'Last 7 days', '4 listens'),
      ('everything', 'Everything', '4 listens'),
    ]) {
      expect(
        find.descendant(of: _option(name), matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _option(name), matching: find.text(count)),
        findsOneWidget,
        reason: name,
      );
    }
  });

  historyTestWidgets('Clear is off until a range with listens is picked', (
    tester,
  ) async {
    await openDialog(tester);
    expect(confirmEnabled(tester), isFalse);

    await tester.tap(_option('lastHour'));
    await tester.pump();
    expect(confirmEnabled(tester), isFalse);

    await tester.tap(_option('today'));
    await tester.pump();
    expect(confirmEnabled(tester), isTrue);
  });

  historyTestWidgets('Cancel comes back to the modal and clears nothing', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(_option('everything'));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await settleModal(tester);

    expect(find.text('Clear history?'), findsNothing);
    expect(_row('clear'), findsOneWidget);
    expect(await playCount(tester), 4);
  });

  historyTestWidgets('Today clears only today and says how many', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(_option('today'));
    await tester.pump();

    await tester.tap(_confirm);
    await settleHistory(tester);

    expect(_row('clear'), findsNothing, reason: 'the modal is closed');
    expect(find.text('Cleared 1 listen from history'), findsOneWidget);
    expect(await playCount(tester), 3);
    final stats = (await tester.runAsync(
      () => h.db.select(h.db.playStats).get(),
    ))!;
    expect(stats.map((s) => s.path), isNot(contains('/m/B.flac')));
  });

  historyTestWidgets('Everything clears all and the page says so', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(_option('everything'));
    await tester.pump();

    await tester.tap(_confirm);
    await settleHistory(tester);

    expect(find.text('Cleared 4 listens from history'), findsOneWidget);
    expect(await playCount(tester), 0);
    expect(find.text('Songs you play will show up here.'), findsOneWidget);
  });

  historyTestWidgets('the day is fixed when the dialog opens', (tester) async {
    await openDialog(tester);
    await tester.tap(_option('today'));
    await tester.pump();

    // Midnight passes while the dialog is open: it still means the 23rd.
    clock = DateTime(2026, 10, 24, 0, 5);
    await tester.tap(_confirm);
    await settleHistory(tester);

    expect(find.text('Cleared 1 listen from history'), findsOneWidget);
  });

  historyTestWidgets('a failing delete says so and keeps the plays', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(_option('everything'));
    await tester.pump();
    await breakWrites(tester, h, 'plays', 'DELETE');

    await tester.tap(_confirm);
    await settleHistory(tester);

    expect(find.text('Could not clear listen history'), findsOneWidget);
    expect(await playCount(tester), 4);
  });

  historyTestWidgets('Clear history is off while another clear runs', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(_more);
    await settleModal(tester);
    await tester.tap(_row('advanced'));
    await settleModal(tester);
    final recorder = h.container.read(listenRecorderProvider)!;
    final release = gate.holdNext('DELETE FROM');

    // Started from Settings, say.
    final running = recorder.clearHistory(from: 0, to: 1);
    await tester.pump();
    await tester.tap(_row('clear'));
    await tester.pump();
    expect(find.text('Clear history?'), findsNothing);

    release();
    await tester.runAsync(() => running);
    await tester.pump();
    await tester.tap(_row('clear'));
    await settleModal(tester);
    expect(find.text('Clear history?'), findsOneWidget);
  });
}
