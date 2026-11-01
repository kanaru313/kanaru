import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_layout_setting_rows.dart';
import 'package:kanaru/features/settings/interface_setting_rows.dart';
import 'package:material_ui/material_ui.dart';

import 'appearance_rows_harness.dart';

/// The Layout group as the Appearance page builds it.
const _layout = Column(
  children: [InterfaceSettingRows(), AppearanceLayoutSettingRows()],
);

void main() {
  testWidgets('the waveform seek bar switch follows track numbers', (
    tester,
  ) async {
    final container = await pumpAppearanceRows(tester, _layout);
    final titles = settingRowTitles(tester);
    expect(
      titles.indexOf('Waveform seek bar'),
      titles.indexOf('Track numbers in albums') + 1,
    );
    expect(titles.last, 'Title bar');
    final toggle = find.descendant(
      of: settingRowTitled('Waveform seek bar'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.waveformSeekBar, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.waveformSeekBar, isTrue);
  });

  testWidgets('a title bar change asks for a restart until changed back', (
    tester,
  ) async {
    final container = await pumpAppearanceRows(
      tester,
      const AppearanceLayoutSettingRows(),
    );
    expect(find.text('Applies after restart'), findsNothing);

    container
        .read(settingsProvider.notifier)
        .setTitleBar(TitleBarPreference.none);
    await tester.pump();
    expect(find.text('Applies after restart'), findsOneWidget);

    container
        .read(settingsProvider.notifier)
        .setTitleBar(container.read(initialSettingsProvider).titleBar);
    await tester.pump();
    expect(find.text('Applies after restart'), findsNothing);
  });
}
