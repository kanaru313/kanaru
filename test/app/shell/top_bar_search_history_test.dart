import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/search/search_prefs_provider.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart'
    show EditableText, FocusManager, IconButton, SearchBar, TextButton;

import '../app_test_harness.dart';

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

List<String> _history(ProviderContainer c) =>
    c.read(searchPrefsProvider).value?.history ?? const [];

bool _fieldFocused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

Future<ProviderContainer> _pumpWith(
  WidgetTester tester,
  List<String> history,
) async {
  final container = await pumpApp(tester);
  for (final entry in history.reversed) {
    await container.read(searchPrefsProvider.notifier).record(entry);
  }
  await tester.pump();
  return container;
}

Future<void> _focusField(WidgetTester tester) async {
  await tester.tap(find.byType(SearchBar));
  await tester.pumpAndSettle();
}

final _removeButtons = find.widgetWithIcon(IconButton, AppIcons.close);

void main() {
  testWidgets('Enter saves the query', (tester) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_history(container), ['abba']);
  });

  testWidgets('typing alone does not save', (tester) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.pump(const Duration(milliseconds: 200));

    expect(_history(container), isEmpty);
  });

  testWidgets('no panel without history', (tester) async {
    await _pumpWith(tester, []);
    await _focusField(tester);

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('no panel while the field has no focus', (tester) async {
    await _pumpWith(tester, ['abba']);

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('a focused empty field lists the history', (tester) async {
    await _pumpWith(tester, ['abba', 'queen']);
    await _focusField(tester);

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('abba'), findsOneWidget);
    expect(find.text('queen'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('typing closes the panel', (tester) async {
    await _pumpWith(tester, ['abba']);
    await _focusField(tester);

    await tester.enterText(find.byType(SearchBar), 'q');
    await tester.pump();

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('choosing a row searches it and moves it first', (tester) async {
    final container = await _pumpWith(tester, ['abba', 'queen']);
    await _focusField(tester);

    await tester.tap(find.text('queen'));
    await tester.pumpAndSettle();

    expect(_location(container), '/search?q=queen');
    expect(_fieldText(tester), 'queen');
    expect(_history(container), ['queen', 'abba']);
    expect(find.text('Recent searches'), findsNothing);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('removing a row keeps the field focused', (tester) async {
    final container = await _pumpWith(tester, ['abba', 'queen']);
    await _focusField(tester);

    await tester.tap(_removeButtons.first);
    await tester.pumpAndSettle();

    expect(_history(container), ['queen']);
    expect(find.text('abba'), findsNothing);
    expect(find.text('queen'), findsOneWidget);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('removing the last row closes the panel', (tester) async {
    await _pumpWith(tester, ['abba']);
    await _focusField(tester);

    await tester.tap(_removeButtons);
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('Clear all empties the history and closes the panel', (
    tester,
  ) async {
    final container = await _pumpWith(tester, ['abba', 'queen']);
    await _focusField(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
    await tester.pumpAndSettle();

    expect(_history(container), isEmpty);
    expect(find.text('Recent searches'), findsNothing);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('arrow keys pick a row and Enter opens it', (tester) async {
    final container = await _pumpWith(tester, ['abba', 'queen', 'toto']);
    await _focusField(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_location(container), '/search?q=abba');
    expect(_history(container).first, 'abba');
  });

  testWidgets('Esc closes the panel and it comes back on focus', (
    tester,
  ) async {
    await _pumpWith(tester, ['abba']);
    await _focusField(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Recent searches'), findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _focusField(tester);
    expect(find.text('Recent searches'), findsOneWidget);
  });

  testWidgets('losing focus closes the panel', (tester) async {
    await _pumpWith(tester, ['abba']);
    await _focusField(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('removing the highlighted row resets the highlight', (
    tester,
  ) async {
    final container = await _pumpWith(tester, ['abba', 'queen', 'toto']);
    await _focusField(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await container.read(searchPrefsProvider.notifier).remove('queen');
    await tester.pump();
    // No row is highlighted any more, so Enter searches the (empty) text.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_location(container), isNot('/search?q=toto'));
    expect(_history(container), ['abba', 'toto']);
  });

  testWidgets('Delete removes the highlighted row', (tester) async {
    final container = await _pumpWith(tester, ['abba', 'queen', 'toto']);
    await _focusField(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_history(container), hasLength(3));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(_history(container), ['abba', 'toto']);
  });

  testWidgets('the highlighted row is marked selected', (tester) async {
    await _pumpWith(tester, ['abba', 'queen']);
    await _focusField(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final handle = tester.ensureSemantics();
    expect(
      find.semantics.byPredicate(
        (n) =>
            n.flagsCollection.isSelected.name == 'isTrue' &&
            n.label.contains('abba'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
