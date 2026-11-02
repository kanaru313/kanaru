import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/context_menu_more_button.dart';
import 'package:material_ui/material_ui.dart';

typedef _Call = ({bool viaKeyboard, Offset at});

Future<void> _pump(WidgetTester tester, List<_Call> calls) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: ContextMenuMoreButton(
            onOpen: ({required viaKeyboard, required at}) =>
                calls.add((viaKeyboard: viaKeyboard, at: at)),
          ),
        ),
      ),
    ),
  );
}

/// The bottom-left of the button's box, in global coordinates.
Offset _bottomLeft(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(ContextMenuMoreButton));

void main() {
  testWidgets('reads "More options"', (tester) async {
    await _pump(tester, []);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byIcon(AppIcons.more), findsOneWidget);
  });

  testWidgets('a click opens at its bottom-left, not from the keyboard', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pump(tester, calls);

    await tester.tap(find.byType(ContextMenuMoreButton));
    await tester.pump();

    expect(calls, [(viaKeyboard: false, at: _bottomLeft(tester))]);
  });

  for (final key in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  ]) {
    testWidgets(
      '${key.keyLabel} on the focused button opens from the keyboard',
      (tester) async {
        final calls = <_Call>[];
        await _pump(tester, calls);
        Focus.of(tester.element(find.byIcon(AppIcons.more))).requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(key);
        await tester.pump();

        expect(calls, [(viaKeyboard: true, at: _bottomLeft(tester))]);
      },
    );
  }
}
