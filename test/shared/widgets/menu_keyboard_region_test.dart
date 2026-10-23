import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/menu_keyboard_region.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

/// A list of three rows, the middle one in a [QueueActionsRegion].
Future<FocusNode> _pumpRows(
  WidgetTester tester,
  List<QueueAction> picked,
) async {
  final focus = FocusNode(debugLabel: 'row');
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 100),
            QueueActionsRegion(
              onAction: picked.add,
              child: InkWell(
                focusNode: focus,
                onTap: () {},
                child: const SizedBox(height: 48, child: Text('row')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return focus;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Shift+F10 on the focused row opens its menu at the row', (
    tester,
  ) async {
    final picked = <QueueAction>[];
    final focus = await _pumpRows(tester, picked);
    focus.requestFocus();
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.f10, shift: true);
    expect(find.text('Play next'), findsOneWidget);
    // Anchored on the row, not at the window's corner.
    final menuTop = tester.getTopLeft(find.text('Play next')).dy;
    expect(menuTop, greaterThan(80));

    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    expect(picked, [QueueAction.addToQueue]);
  });

  testWidgets('the Menu key opens it too, Esc closes it and focus returns', (
    tester,
  ) async {
    final focus = await _pumpRows(tester, []);
    focus.requestFocus();
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.contextMenu);
    expect(find.text('Play next'), findsOneWidget);
    expect(focus.hasPrimaryFocus, isFalse);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Play next'), findsNothing);
    expect(focus.hasPrimaryFocus, isTrue);
  });

  testWidgets('without focus in the row the keys open nothing', (tester) async {
    await _pumpRows(tester, []);

    await _press(tester, LogicalKeyboardKey.f10, shift: true);
    await _press(tester, LogicalKeyboardKey.contextMenu);
    expect(find.text('Play next'), findsNothing);
  });

  testWidgets('F10 without Shift opens nothing', (tester) async {
    final focus = await _pumpRows(tester, []);
    focus.requestFocus();
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.f10);
    expect(find.text('Play next'), findsNothing);
  });

  testWidgets('without onOpen the child is returned as is', (tester) async {
    const child = SizedBox();
    expect(const MenuKeyboardRegion(child: child).build(_FakeContext()), child);
  });
}

class _FakeContext extends Fake implements BuildContext {}
