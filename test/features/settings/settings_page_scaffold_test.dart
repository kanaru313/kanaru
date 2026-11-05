import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/settings_page_scaffold.dart';
import 'package:kanaru/features/settings/settings_save_warning.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  SettingsFile? file,
  Size size = const Size(1600, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsFileProvider.overrideWithValue(file)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const SettingsPageScaffold(
          title: 'Page title',
          children: [
            SettingsSection(title: 'First', children: [Text('row one')]),
            SettingsSection(title: null, children: [Text('row two')]),
            SettingsSection(title: 'Third', children: [Text('row three')]),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the title and the children in order', (tester) async {
    await _pump(tester);

    expect(find.text('Page title'), findsOneWidget);
    final tops = [
      for (final text in ['First', 'row one', 'row two', 'Third', 'row three'])
        tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(tops.length));
  });

  testWidgets('a section without a title has no header', (tester) async {
    await _pump(tester);

    final untitled = find.byWidgetPredicate(
      (w) => w is SettingsSection && w.title == null,
    );
    expect(
      find.descendant(of: untitled, matching: find.byType(Text)),
      findsOneWidget,
      reason: 'only its row',
    );
    final titled = find.byWidgetPredicate(
      (w) => w is SettingsSection && w.title == 'First',
    );
    expect(
      find.descendant(of: titled, matching: find.byType(Text)),
      findsNWidgets(2),
      reason: 'its header and its row',
    );
  });

  testWidgets('the content is at most 720 px wide', (tester) async {
    await _pump(tester);

    // Stretched to the content width, which is capped.
    for (final section in find.byType(SettingsSection).evaluate()) {
      expect(tester.getSize(find.byWidget(section.widget)).width, 720);
    }
  });

  testWidgets('the save warning comes first when settings are read-only', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_scaffold_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/settings.json';
    File(path).writeAsStringSync('{"version": 99}');
    await _pump(tester, file: SettingsFile(path)..load());

    expect(
      find.text("Settings can't be saved this session ($path)"),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byType(SettingsSaveWarning)).dy,
      lessThan(tester.getTopLeft(find.text('First')).dy),
    );
  });

  testWidgets('a section has a bottom spacer after its children', (
    tester,
  ) async {
    await _pump(tester);

    final titled = find.byWidgetPredicate(
      (w) => w is SettingsSection && w.title == 'First',
    );
    final sectionRect = tester.getRect(titled);
    final rowRect = tester.getRect(find.text('row one'));
    expect(sectionRect.bottom - rowRect.bottom, 12);
  });

  testWidgets('no warning when settings are writable', (tester) async {
    await _pump(tester);

    expect(find.byIcon(AppIcons.warningOutlined), findsNothing);
  });
}
