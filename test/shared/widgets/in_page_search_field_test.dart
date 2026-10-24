import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/in_page_filter.dart';
import 'package:kanaru/shared/in_page_filter_host.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

/// A page that owns the filter and registers it, as the real pages do.
class _Page extends StatefulWidget {
  const _Page({required this.filter});

  final InPageFilterController filter;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with InPageFilterHost<_Page> {
  @override
  InPageFilterController get filterController => widget.filter;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      InPageSearchField(controller: widget.filter),
      const SizedBox(width: 10),
      const Focus(child: Text('elsewhere')),
    ],
  );
}

void main() {
  late InPageFilterController filter;

  Future<void> pump(WidgetTester tester) async {
    filter = InPageFilterController();
    addTearDown(filter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: _Page(filter: filter)),
      ),
    );
  }

  Finder box() => find.byType(TextField);

  testWidgets('shows a button that opens the box with focus', (tester) async {
    await pump(tester);
    expect(box(), findsNothing);

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();

    expect(box(), findsOneWidget);
    expect(filter.focus.hasFocus, isTrue);
    expect(tester.getSize(box()).width, lessThanOrEqualTo(280));
  });

  testWidgets('terms follow the text after the debounce', (tester) async {
    await pump(tester);
    filter.open();
    await tester.pumpAndSettle();

    await tester.enterText(box(), 'Love St');
    await tester.pump(const Duration(milliseconds: 50));
    expect(filter.terms, isEmpty, reason: 'still waiting');
    await tester.pump(const Duration(milliseconds: 60));
    expect(filter.terms, ['love', 'st']);
    expect(filter.query, 'Love St');
  });

  testWidgets('the clear button empties the text and keeps the box', (
    tester,
  ) async {
    await pump(tester);
    filter.open();
    await tester.pumpAndSettle();
    await tester.enterText(box(), 'abc');
    await tester.pump(const Duration(milliseconds: 150));
    expect(filter.isFiltering, isTrue);

    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pumpAndSettle();

    expect(filter.isFiltering, isFalse);
    expect(box(), findsOneWidget);
    expect(filter.text.text, isEmpty);
    expect(filter.focus.hasFocus, isTrue);
  });

  testWidgets('Esc clears, closes and returns focus to the button', (
    tester,
  ) async {
    await pump(tester);
    filter.open();
    await tester.pumpAndSettle();
    await tester.enterText(box(), 'abc');
    await tester.pump(const Duration(milliseconds: 150));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(box(), findsNothing);
    expect(filter.terms, isEmpty);
    expect(filter.isOpen, isFalse);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets('an empty box closes when it loses focus; a typed one stays', (
    tester,
  ) async {
    await pump(tester);
    filter.open();
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(box(), findsNothing);

    filter.open();
    await tester.pumpAndSettle();
    await tester.enterText(box(), 'x');
    await tester.pump(const Duration(milliseconds: 150));
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(box(), findsOneWidget);
    expect(filter.terms, ['x']);
  });

  testWidgets('Ctrl+F through the registry opens it and selects the text', (
    tester,
  ) async {
    await pump(tester);
    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();
    expect(box(), findsOneWidget);
    expect(InPageFilterRegistry.instance.hasFocus, isTrue);

    await tester.enterText(box(), 'hello');
    await tester.pump(const Duration(milliseconds: 150));
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    expect(InPageFilterRegistry.instance.hasFocus, isFalse);

    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();
    expect(filter.focus.hasFocus, isTrue);
    expect(
      filter.text.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
  });

  testWidgets('unregisters when the page goes away', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(InPageFilterRegistry.instance.openTop(), isFalse);
  });
}
