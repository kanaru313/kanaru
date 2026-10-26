import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/display_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: DisplaySettingRows()),
          ),
        ),
      ),
    );
  }

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(SettingRow));

  testWidgets('the colors from the cover switch is live', (tester) async {
    await pump(tester);
    final colorRow = tester.widget<SettingRow>(row('Colors from the cover'));
    expect(colorRow.comingSoon, isFalse);
    expect(
      find.descendant(
        of: row('Colors from the cover'),
        matching: find.text('Coming soon'),
      ),
      findsNothing,
    );

    final toggle = find.descendant(
      of: row('Colors from the cover'),
      matching: find.byType(Switch),
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.colorFromCover, isTrue);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).display.colorFromCover, isFalse);
  });

  testWidgets('the waveform seek bar switch follows the colors row', (
    tester,
  ) async {
    await pump(tester);
    final titles = tester
        .widgetList<SettingRow>(find.byType(SettingRow))
        .map((r) => r.title)
        .toList();
    expect(
      titles.indexOf('Waveform seek bar'),
      titles.indexOf('Colors from the cover') + 1,
    );
    final toggle = find.descendant(
      of: row('Waveform seek bar'),
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

  testWidgets('the animations switch is live', (tester) async {
    await pump(tester);
    expect(tester.widget<SettingRow>(row('Animations')).comingSoon, isFalse);
    final toggle = find.descendant(
      of: row('Animations'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(settingsProvider).animations, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('the text size dropdown saves the picked size', (tester) async {
    await pump(tester);
    expect(tester.widget<SettingRow>(row('Text size')).comingSoon, isFalse);

    await tester.tap(
      find.descendant(of: row('Text size'), matching: find.byType(TextField)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '125%').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).display.fontScale, 1.25);
  });
}
