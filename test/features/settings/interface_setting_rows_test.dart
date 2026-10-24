import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/interface_setting_rows.dart';
import 'package:kanaru/l10n/l10n.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Set<SidebarTab> tabs,
) async {
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        AppSettings(display: DisplayPrefs(sidebarTabs: tabs)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: InterfaceSettingRows()),
        ),
      ),
    ),
  );
  return container;
}

FilterChip _chip(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(FilterChip, label));

void main() {
  testWidgets('chips follow the sidebar order and are not coming soon', (
    tester,
  ) async {
    await _pump(tester, SidebarTab.values.toSet());

    final labels = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .map((c) => (c.label as Text).data);
    expect(labels, [
      'Songs',
      'Albums',
      'Artists',
      'Genres',
      'Languages',
      'Folders',
    ]);
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets('a chip writes the tab to the settings', (tester) async {
    final container = await _pump(tester, SidebarTab.values.toSet());

    await tester.tap(find.widgetWithText(FilterChip, 'Genres'));
    await tester.pump();
    expect(
      container.read(settingsProvider).display.sidebarTabs,
      isNot(contains(SidebarTab.genres)),
    );
    expect(_chip(tester, 'Genres').selected, isFalse);

    await tester.tap(find.widgetWithText(FilterChip, 'Genres'));
    await tester.pump();
    expect(
      container.read(settingsProvider).display.sidebarTabs,
      contains(SidebarTab.genres),
    );
  });

  testWidgets('the last selected chip cannot be turned off', (tester) async {
    final container = await _pump(tester, {SidebarTab.albums});

    expect(_chip(tester, 'Albums').onSelected, isNull);
    expect(_chip(tester, 'Songs').onSelected, isNotNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Albums'));
    await tester.pump();
    expect(container.read(settingsProvider).display.sidebarTabs, {
      SidebarTab.albums,
    });
  });
}
