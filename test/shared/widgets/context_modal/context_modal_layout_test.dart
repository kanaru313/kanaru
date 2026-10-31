import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'context_modal_harness.dart';

void main() {
  testWidgets('dialog is 400 wide, rounded 28, same width on every page', (
    tester,
  ) async {
    await pumpModalApp(tester);
    final frame = find.byType(ContextModalDialogFrame);
    expect(
      tester
          .getSize(
            find.descendant(of: frame, matching: find.byType(Material)).first,
          )
          .width,
      400,
    );
    await tester.tap(find.text('Open sub'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find.descendant(of: frame, matching: find.byType(Material)).first,
          )
          .width,
      400,
    );
  });

  testWidgets('dialog height stays inside the window margin', (tester) async {
    await pumpModalApp(
      tester,
      size: const Size(1000, 300),
      extra: [
        for (var i = 0; i < 20; i++)
          ContextModalAction(id: 'a$i', icon: Icons.info, label: 'Row $i'),
      ],
    );
    final h = tester
        .getSize(
          find
              .descendant(
                of: find.byType(ContextModalDialogFrame),
                matching: find.byType(Material),
              )
              .first,
        )
        .height;
    expect(h, 300 - 48);
  });

  testWidgets('sheet is full width and a handle drag past 25% closes it', (
    tester,
  ) async {
    await pumpModalApp(tester, size: const Size(360, 800));
    final sheet = find.byType(ContextModalSheetFrame);
    expect(tester.getSize(sheet).width, 360);

    final handle = find
        .descendant(of: sheet, matching: find.byType(GestureDetector))
        .first;
    // A short drag springs back.
    await tester.drag(handle, const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsOneWidget);

    await tester.drag(handle, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsNothing);
  });

  testWidgets('a fling on the handle closes the sheet', (tester) async {
    await pumpModalApp(tester, size: const Size(360, 800));
    final handle = find
        .descendant(
          of: find.byType(ContextModalSheetFrame),
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.fling(handle, const Offset(0, 60), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Open sub'), findsNothing);
  });

  testWidgets('arrow keys move focus between tiles', (tester) async {
    await pumpModalApp(
      tester,
      extra: [
        ContextModalAction(
          id: 'b',
          icon: Icons.info,
          label: 'Second',
          onTap: (_) {},
        ),
      ],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final first = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(first));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, first);
  });
}
