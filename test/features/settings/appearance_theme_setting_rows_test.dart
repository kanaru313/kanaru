import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_theme_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import 'appearance_rows_harness.dart';

void main() {
  testWidgets('the rows come in order: theme, colors, animations', (
    tester,
  ) async {
    await pumpAppearanceRows(tester, const AppearanceThemeSettingRows());

    expect(settingRowTitles(tester), [
      'Theme',
      'Colors from the cover',
      'Animations',
    ]);
  });

  testWidgets('the colors from the cover switch is live', (tester) async {
    final container = await pumpAppearanceRows(
      tester,
      const AppearanceThemeSettingRows(),
    );
    final colorRow = tester.widget<SettingRow>(
      settingRowTitled('Colors from the cover'),
    );
    expect(colorRow.comingSoon, isFalse);
    expect(
      find.descendant(
        of: settingRowTitled('Colors from the cover'),
        matching: find.text('Coming soon'),
      ),
      findsNothing,
    );

    final toggle = find.descendant(
      of: settingRowTitled('Colors from the cover'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.colorFromCover, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.colorFromCover, isTrue);
  });

  testWidgets('the animations switch is live', (tester) async {
    final container = await pumpAppearanceRows(
      tester,
      const AppearanceThemeSettingRows(),
    );
    expect(
      tester.widget<SettingRow>(settingRowTitled('Animations')).comingSoon,
      isFalse,
    );
    final toggle = find.descendant(
      of: settingRowTitled('Animations'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).animations, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });
}
