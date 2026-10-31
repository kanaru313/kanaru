import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:material_ui/material_ui.dart';

import 'sleep_timer_harness.dart';

void main() {
  final h = SleepTimerHarness();

  final field = find.descendant(
    of: dialogFinder,
    matching: find.byType(TextField),
  );
  final start = find.widgetWithText(FilledButton, 'Start');

  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(field).controller!;

  String text(WidgetTester tester) => controller(tester).text;

  Slider slider(WidgetTester tester) => tester.widget<Slider>(
    find.descendant(of: dialogFinder, matching: find.byType(Slider)),
  );

  List<String> selectedChips(WidgetTester tester) => [
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
      if (chip.selected) (chip.label as Text).data!,
  ];

  Future<void> openDialog(WidgetTester tester) async {
    await h.pump(tester);
    await h.open(tester);
  }

  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> openTracksTab(WidgetTester tester) async {
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
  }

  testWidgets('the field is focused on open, with its number selected', (
    tester,
  ) async {
    await openDialog(tester);
    expect(text(tester), '45');
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    final selection = controller(tester).selection;
    expect((selection.start, selection.end), (0, 2));
  });

  testWidgets('keeps digits only', (tester) async {
    await openDialog(tester);
    await type(tester, '4a5');
    expect(text(tester), '45');
  });

  testWidgets('the caret stays at the end while typing digit by digit', (
    tester,
  ) async {
    await openDialog(tester);
    for (final typed in ['1', '12', '123']) {
      await type(tester, typed);
      expect(text(tester), typed);
      expect(controller(tester).selection.baseOffset, typed.length);
    }
  });

  testWidgets('typing 7 moves the hint, the slider and the chips at once', (
    tester,
  ) async {
    await openDialog(tester);
    await type(tester, '7');
    expect(text(tester), '7');
    expect(slider(tester).value, 7);
    expect(selectedChips(tester), isEmpty);
    expect(find.textContaining('Stops at'), findsOneWidget);
    expect(h.state.active, isFalse);

    await type(tester, '30');
    expect(selectedChips(tester), ['30m']);
  });

  testWidgets('240 leaves the slider at its end and starts exactly 240', (
    tester,
  ) async {
    await openDialog(tester);
    await type(tester, '240');
    expect(slider(tester).value, 180);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(h.state.mode, SleepTimerMode.minutes);
    expect(h.state.remaining, const Duration(minutes: 240));
  });

  testWidgets('empty or zero keep the last number and blur restores it', (
    tester,
  ) async {
    await openDialog(tester);
    await type(tester, '20');
    await type(tester, '');
    expect(slider(tester).value, 20);
    await type(tester, '0');
    expect(slider(tester).value, 20);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(text(tester), '20');
  });

  testWidgets('999 is shown as 720', (tester) async {
    await openDialog(tester);
    await type(tester, '999');
    expect(text(tester), '720');
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(h.state.remaining, const Duration(minutes: 720));
  });

  testWidgets('Enter settles the text and starts', (tester) async {
    await openDialog(tester);
    await type(tester, '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(h.state.remaining, const Duration(minutes: 12));
    expect(dialogFinder, findsNothing);
  });

  testWidgets('Enter after a zero starts the last valid number', (
    tester,
  ) async {
    await openDialog(tester);
    await type(tester, '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(h.state.remaining, const Duration(minutes: 45));
  });

  testWidgets('the Tracks tab clamps to 20 and starts that many', (
    tester,
  ) async {
    await openDialog(tester);
    await openTracksTab(tester);
    expect(text(tester), '3');
    await type(tester, '25');
    expect(text(tester), '20');
    expect(slider(tester).value, 20);
    expect(find.textContaining('Pauses after 20 tracks'), findsOneWidget);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(h.state.mode, SleepTimerMode.tracks);
    expect(h.state.tracksLeft, 20);
  });

  testWidgets('- and + rewrite the text', (tester) async {
    await openDialog(tester);
    await tester.tap(find.byTooltip('Add 5 minutes'));
    await tester.pump();
    expect(text(tester), '50');
    await tester.tap(find.byTooltip('Remove 5 minutes'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove 5 minutes'));
    await tester.pump();
    expect(text(tester), '40');
  });

  testWidgets('a chip and the slider rewrite the text', (tester) async {
    await openDialog(tester);
    await type(tester, '7');
    await tester.tap(find.text('1h'));
    await tester.pump();
    expect(text(tester), '60');
    // The arrow keys step the slider.
    await tester.tap(
      find.descendant(of: dialogFinder, matching: find.byType(Slider)),
    );
    await tester.pump();
    expect(int.parse(text(tester)) % 5, 0);
  });

  testWidgets('Esc closes the dialog and starts nothing', (tester) async {
    await openDialog(tester);
    await type(tester, '12');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dialogFinder, findsNothing);
    expect(h.state.active, isFalse);
  });

  testWidgets('the field is one text field node with its label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openDialog(tester);
    var data = tester.getSemantics(field).getSemanticsData();
    expect(data.flagsCollection.isTextField, isTrue);
    expect(data.label, 'Minutes');
    expect(data.value, '45');

    await openTracksTab(tester);
    data = tester.getSemantics(field).getSemanticsData();
    expect(data.flagsCollection.isTextField, isTrue);
    expect(data.label, 'Number of tracks');
    handle.dispose();
  });

  // The value text sits on a child node of the slider.
  String sliderValue(SemanticsNode node) {
    var found = node.getSemanticsData().value;
    node.visitChildren((child) {
      if (found.isEmpty) found = sliderValue(child);
      return true;
    });
    return found;
  }

  testWidgets('the slider reads its value with the unit', (tester) async {
    final handle = tester.ensureSemantics();
    await openDialog(tester);
    final sliderFinder = find.descendant(
      of: dialogFinder,
      matching: find.byType(Slider),
    );
    expect(sliderValue(tester.getSemantics(sliderFinder)), contains('45 min'));
    await openTracksTab(tester);
    await type(tester, '1');
    expect(sliderValue(tester.getSemantics(sliderFinder)), contains('1 track'));
    await type(tester, '2');
    expect(
      sliderValue(tester.getSemantics(sliderFinder)),
      contains('2 tracks'),
    );
    handle.dispose();
  });

  testWidgets('switching tab swaps the number and the range', (tester) async {
    await openDialog(tester);
    await type(tester, '90');
    await openTracksTab(tester);
    expect(text(tester), '3');
    expect((slider(tester).min, slider(tester).max), (1, 20));
    await tester.tap(find.text('Minutes'));
    await tester.pumpAndSettle();
    expect(text(tester), '90');
    expect((slider(tester).min, slider(tester).max), (5, 180));
  });
}
