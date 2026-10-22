import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

Finder _inRow(String title, Finder control) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
  matching: control,
);

Future<LibraryHarness> _open(
  WidgetTester tester, {
  required bool hasDatabase,
}) async {
  final h = LibraryHarness(
    hasDatabase: hasDatabase,
    overrides: [
      initialSettingsProvider.overrideWithValue(
        const AppSettings(libraryOnboarded: true),
      ),
    ],
  );
  await h.pump(tester);
  tester.view.physicalSize = const Size(1280, 4000);
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('the skip rows are saved and carry no badge', (tester) async {
    final h = await _open(tester, hasDatabase: true);
    LibraryScanPrefs scan() => h.container.read(settingsProvider).libraryScan;

    for (final title in [
      'Skip folders with .nomedia',
      'Minimum file size',
      'Minimum length',
    ]) {
      final row = tester.widget<SettingRow>(
        find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
      );
      expect(row.comingSoon, isFalse, reason: title);
    }

    await tester.tap(_inRow('Skip folders with .nomedia', find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(scan().respectNomedia, isTrue);

    await tester.tap(_inRow('Minimum file size', find.byType(TextField)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '500 KB').last);
    await tester.pumpAndSettle();
    expect(scan().minFileSizeKb, 500);

    await tester.tap(_inRow('Minimum length', find.byType(TextField)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '30 s').last);
    await tester.pumpAndSettle();
    expect(scan().minDurationSeconds, 30);
    expect(scan().respectNomedia, isTrue, reason: 'other options are kept');
  });

  testWidgets('without a library database the skip rows are disabled', (
    tester,
  ) async {
    final h = await _open(tester, hasDatabase: false);

    final nomedia = tester.widget<Switch>(
      _inRow('Skip folders with .nomedia', find.byType(Switch)),
    );
    expect(nomedia.onChanged, isNull);
    for (final title in ['Minimum file size', 'Minimum length']) {
      expect(
        tester.widget<TextField>(_inRow(title, find.byType(TextField))).enabled,
        isFalse,
        reason: title,
      );
    }
    expect(
      h.container.read(settingsProvider).libraryScan,
      const LibraryScanPrefs(),
    );
  });
}
