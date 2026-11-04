import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] (an Appearance row group) alone in a localized app and
/// returns the container behind it. [fontId] is stored before the first
/// frame.
Future<ProviderContainer> pumpAppearanceRows(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  String? fontId,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  if (fontId != null) {
    final s = container.read(settingsProvider);
    container
        .read(settingsProvider.notifier)
        .setDisplay(s.display.copyWith(fontId: fontId));
  }
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  return container;
}

/// The [SettingRow] titled [title].
Finder settingRowTitled(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SettingRow));

/// The titles of the rows shown, top to bottom.
List<String> settingRowTitles(WidgetTester tester) => tester
    .widgetList<SettingRow>(find.byType(SettingRow))
    .map((r) => r.title)
    .toList();
