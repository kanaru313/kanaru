import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:material_ui/material_ui.dart' show EditableText, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation_history_test.dart' show pumpApp;

const _pause = Duration(milliseconds: 150);

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  testWidgets('typing opens search after a short pause', (tester) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(container), '/home');

    await tester.pump(const Duration(milliseconds: 50));
    expect(_location(container), '/search?q=abba');
  });

  testWidgets('typing a word leaves one history entry', (tester) async {
    final container = await pumpApp(tester);

    for (final text in ['a', 'ab', 'abb', 'abba']) {
      await tester.enterText(find.byType(SearchBar), text);
      await tester.pump(_pause);
    }

    expect(container.read(navigationHistoryProvider).entries, [
      '/home',
      '/search?q=abba',
    ]);
  });

  testWidgets('Enter searches at once', (tester) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_location(container), '/search?q=abba');
    await tester.pump(_pause);
  });

  testWidgets('a trailing space being typed is kept', (tester) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'abba ');
    await tester.pump(_pause);
    await tester.pumpAndSettle();

    expect(_location(container), '/search?q=abba');
    expect(_fieldText(tester), 'abba ');
  });

  testWidgets('letters typed while the last search loads are kept', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.enterText(find.byType(SearchBar), 'ab');
    await tester.pump(_pause);
    await tester.enterText(find.byType(SearchBar), 'abc');
    await tester.pump();

    expect(_location(container), '/search?q=ab');
    expect(_fieldText(tester), 'abc');
    await tester.pump(_pause);
    expect(_location(container), '/search?q=abc');
    expect(_fieldText(tester), 'abc');
  });

  testWidgets('clearing the field shows the empty search page', (tester) async {
    final container = await pumpApp(tester);
    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.pump(_pause);

    await tester.enterText(find.byType(SearchBar), '');
    await tester.pump(_pause);

    expect(_location(container), '/search');
  });

  testWidgets('back clears the field and forward restores the search text', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final history = container.read(navigationHistoryProvider.notifier);
    await tester.enterText(find.byType(SearchBar), 'son');
    await tester.pump(_pause);
    await tester.pumpAndSettle();

    history.back();
    await tester.pumpAndSettle();
    expect(_location(container), '/home');
    expect(_fieldText(tester), '');

    history.forward();
    await tester.pumpAndSettle();
    expect(_location(container), '/search?q=son');
    expect(_fieldText(tester), 'son');
  });

  testWidgets('leaving search before the pause ends stays on the new page', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.pump(const Duration(milliseconds: 100));

    container.read(routerProvider).go('/albums');
    await tester.pump();
    await tester.pump(_pause * 2);

    expect(_location(container), '/albums');
    expect(_fieldText(tester), '');
  });

  testWidgets('the field keeps focus while results update', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(SearchBar));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(SearchBar), 'abba');
    await tester.pump(_pause);
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
  });
}
