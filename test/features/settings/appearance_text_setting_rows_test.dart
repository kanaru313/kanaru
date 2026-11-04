import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_text_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
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
    testWidgets('comes first, above text size and language, and shows Nunito', (
      tester,
    ) async {
      await pumpAppearanceRows(tester, rows);
      expect(settingRowTitles(tester), ['Text size', 'Language']);
      expect(find.widgetWithText(ListTile, 'Font'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Font'),
          matching: find.text('Nunito'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Font'),
          matching: find.byIcon(AppIcons.chevronRight),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unknown stored id shows Nunito', (tester) async {
      await pumpAppearanceRows(tester, rows, fontId: 'futurefont');
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Font'),
          matching: find.text('Nunito'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the System entry is localized', (tester) async {
      await pumpAppearanceRows(
        tester,
        rows,
        locale: const Locale('vi'),
        fontId: 'system',
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Phông chữ'),
          matching: find.text('Hệ thống'),
        ),
        findsOneWidget,
      );
    });
  });
}
