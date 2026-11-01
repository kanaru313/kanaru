import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_text_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import 'appearance_rows_harness.dart';

void main() {
  const rows = AppearanceTextSettingRows();

  testWidgets('the text size dropdown saves the picked size', (tester) async {
    final container = await pumpAppearanceRows(tester, rows);
    expect(
      tester.widget<SettingRow>(settingRowTitled('Text size')).comingSoon,
      isFalse,
    );

    await tester.tap(
      find.descendant(
        of: settingRowTitled('Text size'),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '125%').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).display.fontScale, 1.25);
  });

  group('font row', () {
    Finder field() => find.descendant(
      of: settingRowTitled('Font'),
      matching: find.byType(TextField),
    );

    testWidgets('comes first, above text size and language, and shows Nunito', (
      tester,
    ) async {
      await pumpAppearanceRows(tester, rows);
      expect(settingRowTitles(tester), ['Font', 'Text size', 'Language']);
      expect(tester.widget<TextField>(field()).controller?.text, 'Nunito');
    });

    testWidgets('options render in their own font; picking saves it', (
      tester,
    ) async {
      final container = await pumpAppearanceRows(tester, rows);
      await tester.tap(field());
      await tester.pumpAndSettle();

      // The language dropdown has a System entry too, in the default font.
      Iterable<String?> families(String label) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.widgetWithText(MenuItemButton, label),
              matching: find.text(label),
            ),
          )
          .map((t) => t.style?.fontFamily);
      for (final label in ['System', 'Inter', 'Nunito']) {
        expect(find.widgetWithText(MenuItemButton, label), findsWidgets);
      }
      expect(families('System'), contains('sans-serif'));
      expect(families('Inter'), contains('Inter'));
      expect(families('Nunito'), contains('Nunito'));

      await tester.tap(find.widgetWithText(MenuItemButton, 'Inter').last);
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).display.fontId, 'inter');
    });

    testWidgets('an unknown stored id shows Nunito', (tester) async {
      await pumpAppearanceRows(tester, rows, fontId: 'futurefont');
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(field()).controller?.text, 'Nunito');
    });

    testWidgets('the System entry is localized', (tester) async {
      await pumpAppearanceRows(
        tester,
        rows,
        locale: const Locale('vi'),
        fontId: 'system',
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: settingRowTitled('Phông chữ'),
                matching: find.byType(TextField),
              ),
            )
            .controller
            ?.text,
        'Hệ thống',
      );
    });
  });
}
