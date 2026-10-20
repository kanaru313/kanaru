import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/setting_choice.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('choosing a value keeps keyboard focus on the dropdown', (
    tester,
  ) async {
    var selected = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 200,
                child: SettingDropdown<String>(
                  options: const [
                    SettingOption(value: 'a', label: 'Alpha'),
                    SettingOption(value: 'b', label: 'Beta'),
                  ],
                  selected: selected,
                  onSelected: (v) => setState(() => selected = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    bool focusInDropdown() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      return context.findAncestorWidgetOfExactType<DropdownMenu<String>>() !=
          null;
    }

    expect(focusInDropdown(), isTrue, reason: 'Tab focuses the dropdown');

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();

    expect(selected, 'b');
    expect(focusInDropdown(), isTrue, reason: 'focus survives the choice');
  });
}
