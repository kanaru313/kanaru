import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';

import 'context_modal_harness.dart';

void main() {
  testWidgets('Esc and Backspace pop a page; Esc closes at the root', (
    tester,
  ) async {
    await pumpModalApp(tester);
    await tester.tap(find.text('Open sub'));
    await tester.pumpAndSettle();
    expect(find.text('Sub page'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsOneWidget);

    await tester.tap(find.text('Open sub'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsNothing);
  });

  testWidgets('Backspace at the root keeps the modal open', (tester) async {
    await pumpModalApp(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsOneWidget);
  });

  testWidgets('the back arrow pops and a scrim tap closes', (tester) async {
    await pumpModalApp(tester);
    await tester.tap(find.text('Open sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsNothing);
  });

  testWidgets('resizing 800 to 360 keeps page two and becomes a sheet', (
    tester,
  ) async {
    await pumpModalApp(tester, size: const Size(800, 800));
    await tester.tap(find.text('Open sub'));
    await tester.pumpAndSettle();
    expect(find.byType(ContextModalDialogFrame), findsOneWidget);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.byType(ContextModalDialogFrame), findsNothing);
    expect(find.text('Sub page'), findsOneWidget);
  });

  testWidgets('reduced motion swaps pages without a slide', (tester) async {
    await pumpModalApp(tester, disableAnimations: true);
    await tester.tap(find.text('Open sub'));
    await tester.pump();
    expect(find.text('Sub page'), findsOneWidget);
    expect(find.text('Open sub'), findsNothing);
  });

  testWidgets('animated page change keeps both pages until it ends', (
    tester,
  ) async {
    await pumpModalApp(tester);
    await tester.tap(find.text('Open sub'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Open sub'), findsOneWidget);
    expect(find.text('Sub page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsNothing);
  });

  group('keyboard focus', () {
    setUp(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });
    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    bool focusIsOn(String label) {
      final focus = FocusManager.instance.primaryFocus;
      // The modal's own scope holds focus while no row does.
      if (focus is FocusScopeNode) return false;
      final ctx = focus?.context;
      if (ctx == null) return false;
      return find
          .descendant(
            of: find.byElementPredicate((e) => e == ctx),
            matching: find.text(label),
          )
          .evaluate()
          .isNotEmpty;
    }

    testWidgets('opening from the keyboard focuses the first row', (
      tester,
    ) async {
      await pumpModalApp(tester, viaKeyboard: true);
      expect(focusIsOn('Open sub'), isTrue);
    });

    testWidgets('opening without the keyboard leaves no row focused', (
      tester,
    ) async {
      await pumpModalApp(tester);
      expect(focusIsOn('Open sub'), isFalse);
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    });

    testWidgets('an arrow with nothing focused lands on the first row', (
      tester,
    ) async {
      await pumpModalApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusIsOn('Open sub'), isTrue);
    });

    testWidgets('the first Tab with nothing focused lands on the first row', (
      tester,
    ) async {
      await pumpModalApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsOn('Open sub'), isTrue);
    });

    testWidgets('a mouse click into a sub page and back leaves focus unset', (
      tester,
    ) async {
      await pumpModalApp(tester);
      await tester.tap(find.text('Open sub'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open sub'), findsOneWidget);
      expect(focusIsOn('Open sub'), isFalse);
      expect(focusIsOn('Leaf action'), isFalse);
    });

    testWidgets('a pointer press after keyboard use ends keyboard mode', (
      tester,
    ) async {
      await pumpModalApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusIsOn('Open sub'), isTrue);
      await tester.tap(find.text('Open sub'));
      await tester.pumpAndSettle();
      expect(focusIsOn('Leaf action'), isFalse);
      expect(focusIsOn('Open sub'), isFalse);
    });

    testWidgets('a mouse click into a sub page focuses no row', (tester) async {
      await pumpModalApp(tester);
      await tester.tap(find.text('Open sub'));
      await tester.pumpAndSettle();
      expect(find.text('Leaf action'), findsOneWidget);
      expect(focusIsOn('Leaf action'), isFalse);
      expect(focusIsOn('Open sub'), isFalse);
    });

    testWidgets('push and pop leave focus on a row of the shown page', (
      tester,
    ) async {
      await pumpModalApp(tester, viaKeyboard: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // The first focusable of the sub page is its back arrow.
      expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
      expect(focusIsOn('Open sub'), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(focusIsOn('Open sub'), isTrue);
    });
  });
}
