import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/in_page_filter.dart';
import 'package:kanaru/shared/widgets/expanding_search_bar.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late InPageFilterController filter;

  final box = find.byType(InPageSearchBox);
  final shown = find.ancestor(of: box, matching: find.byType(SizeTransition));
  final openButton = find.byTooltip('Filter in this page');
  final closeButton = find.byTooltip('Close');

  Future<void> pump(WidgetTester tester) async {
    filter = InPageFilterController();
    addTearDown(filter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: ExpandingSearchBar(
              controller: filter,
              child: const Text('3 songs'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the box grows out of the button over the child, and the '
      'button turns into a close button', (tester) async {
    await pump(tester);
    expect(box, findsNothing);
    final start = tester.getTopLeft(find.text('3 songs')).dx;

    await tester.tap(openButton);
    await tester.pump();
    await tester.pump(expandingSearchDuration ~/ 2);
    final half = tester.getTopLeft(shown).dx;
    expect(half, greaterThan(start));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(shown).dx, moreOrLessEquals(start));
    expect(
      tester.getTopRight(shown).dx,
      lessThanOrEqualTo(tester.getTopLeft(closeButton).dx),
    );
    expect(
      find.descendant(of: box, matching: find.byIcon(AppIcons.search)),
      findsOneWidget,
    );
    expect(openButton, findsNothing);
    expect(filter.focus.hasFocus, isTrue);

    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(box, findsNothing);
    expect(filter.isOpen, isFalse);
    expect(openButton, findsOneWidget);
  });

  testWidgets('a mouse click on the close button closes an empty, focused '
      'box for good', (tester) async {
    await pump(tester);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    expect(filter.focus.hasFocus, isTrue);

    // Frames pass between press and release, as with a real click.
    final click = await tester.startGesture(
      tester.getCenter(closeButton),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    await click.up();
    await tester.pumpAndSettle();
    expect(box, findsNothing);
    expect(openButton, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Esc closes the box and gives the focus back to the button', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'love');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(box, findsNothing);
    expect(filter.text.text, isEmpty);
    final button = tester.widget<IconButton>(
      find.ancestor(of: openButton, matching: find.byType(IconButton)),
    );
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the button is named once, reports its state and taps through '
      'semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    var node = tester.getSemantics(openButton);
    expect(node.label, 'Filter in this page');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isFalse);

    tester.semantics.tap(find.semantics.byLabel('Filter in this page'));
    await tester.pumpAndSettle();
    expect(filter.isOpen, isTrue);
    node = tester.getSemantics(closeButton);
    expect(node.label, 'Close');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isTrue);

    tester.semantics.tap(find.semantics.byLabel('Close'));
    await tester.pumpAndSettle();
    expect(filter.isOpen, isFalse);
    handle.dispose();
  });
}
