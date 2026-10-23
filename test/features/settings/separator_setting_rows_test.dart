import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

Finder _rowButton(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
  matching: find.byType(FilledButton),
);

Future<LibraryHarness> _open(
  WidgetTester tester, {
  required bool hasDatabase,
  AppSettings settings = const AppSettings(libraryOnboarded: true),
}) async {
  final h = LibraryHarness(
    hasDatabase: hasDatabase,
    overrides: [initialSettingsProvider.overrideWithValue(settings)],
  );
  await h.pump(tester);
  tester.view.physicalSize = const Size(1280, 4000);
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('rows summarise the rules and open their dialogs', (
    tester,
  ) async {
    final h = await _open(tester, hasDatabase: true);

    expect(find.text('Split artists'), findsOneWidget);
    expect(find.text('Split genres'), findsOneWidget);
    expect(
      find.text(
        'Applies at once, the library updates in the background.\n'
        '8 separators · 1 kept whole',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Applies at once, no rescan needed.\n1 separator · 0 kept whole',
      ),
      findsOneWidget,
    );

    await tester.tap(_rowButton('Split artists'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '&',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(
      h.container.read(settingsProvider).libraryScan.artistSplit.separators,
      contains('&'),
    );
    // The row shows the new count behind the closed dialog.
    expect(find.textContaining('9 separators · 1 kept whole'), findsOneWidget);

    await tester.tap(_rowButton('Split genres'));
    await tester.pumpAndSettle();
    expect(find.text('Split genres'), findsNWidgets(2));
  });

  testWidgets('without a library database the buttons are off', (tester) async {
    await _open(tester, hasDatabase: false);

    for (final title in ['Split artists', 'Split genres']) {
      expect(
        tester.widget<FilledButton>(_rowButton(title)).onPressed,
        isNull,
        reason: title,
      );
    }
  });
}
