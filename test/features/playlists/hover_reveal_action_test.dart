import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/hover_reveal_action.dart';
import 'package:material_ui/material_ui.dart';

Widget _app() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: HoverRevealAction(
        builder: (_, revealed) => SizedBox(
          width: 300,
          height: 80,
          child: Row(
            children: [
              const Expanded(child: InkWell(onTap: null, child: Text('row'))),
              RevealableAction(
                revealed: revealed,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  testWidgets('hidden at rest but keeps its box', (tester) async {
    await tester.pumpWidget(_app());
    expect(_opacity(tester), 0);
    expect(tester.getSize(find.byType(IconButton)), isNot(Size.zero));
    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(
              of: find.byType(RevealableAction),
              matching: find.byType(IgnorePointer),
            ),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('revealed while the mouse is over the row', (tester) async {
    await tester.pumpWidget(_app());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('row')));
    await tester.pump();
    expect(_opacity(tester), 1);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(_opacity(tester), 0);
  });

  testWidgets('revealed by keyboard focus on the row, then the button', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The row's InkWell has no onTap so it is not focusable; focus lands on
    // the hidden button, which reveals it.
    expect(_opacity(tester), 1);
  });
}
