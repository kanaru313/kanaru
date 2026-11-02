import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_menu_region.dart';
import 'package:material_ui/material_ui.dart';

typedef _Call = ({bool viaKeyboard, Offset at});

/// A focusable 48 px row at y = 100 in a [ContextMenuRegion] that records
/// each open.
Future<FocusNode> _pump(WidgetTester tester, List<_Call> calls) async {
  final focus = FocusNode(debugLabel: 'row');
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 100),
            ContextMenuRegion(
              onOpen: ({required viaKeyboard, required at}) =>
                  calls.add((viaKeyboard: viaKeyboard, at: at)),
              child: InkWell(
                focusNode: focus,
                onTap: () {},
                child: const SizedBox(
                  height: 48,
                  width: 300,
                  child: Text('row'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return focus;
}

void main() {
  testWidgets('a right click opens at the pointer, not from the keyboard', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pump(tester, calls);

    await tester.tapAt(const Offset(150, 110), buttons: kSecondaryButton);
    await tester.pump();

    expect(calls, [(viaKeyboard: false, at: const Offset(150, 110))]);
  });

  testWidgets('a long press opens at the pointer, not from the keyboard', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pump(tester, calls);

    await tester.longPressAt(const Offset(60, 130));
    await tester.pump();

    expect(calls, [(viaKeyboard: false, at: const Offset(60, 130))]);
  });

  testWidgets('the Menu key and Shift+F10 open from the keyboard at the row', (
    tester,
  ) async {
    final calls = <_Call>[];
    final focus = await _pump(tester, calls);
    focus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    // The row starts at y = 100 and is 48 px high: 24 px in, halfway down.
    const anchor = Offset(24, 124);
    expect(calls, [
      (viaKeyboard: true, at: anchor),
      (viaKeyboard: true, at: anchor),
    ]);
  });

  testWidgets('without onOpen the child is returned as is', (tester) async {
    const child = SizedBox();
    expect(
      const ContextMenuRegion(onOpen: null, child: child).build(_FakeContext()),
      child,
    );
  });
}

class _FakeContext extends Fake implements BuildContext {}
