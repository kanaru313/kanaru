import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'picker_test_host.dart';

/// Text in the name dialog's field.
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _openNameDialog(WidgetTester tester) async {
  await tester.tap(inPicker(find.text('New playlist…')));
  await tester.pumpAndSettle();
}

Future<void> _create(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first New playlist offers the suggested name', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      configure: (h) => h.suggestedName = 'Friday mix',
    );
    await openPicker(tester);

    await _openNameDialog(tester);

    expect(_fieldText(tester), 'Friday mix');
  });

  testWidgets('a second New playlist is numbered from the default name', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      configure: (h) => h.suggestedName = 'Friday mix',
    );
    await openPicker(tester);
    await _openNameDialog(tester);
    await _create(tester);

    await _openNameDialog(tester);

    expect(_fieldText(tester), 'New playlist 2');
  });

  testWidgets('without a suggestion the default name is offered', (
    tester,
  ) async {
    await pumpPickerHost(tester);
    await openPicker(tester);

    await _openNameDialog(tester);

    expect(_fieldText(tester), 'New playlist');
  });
}
