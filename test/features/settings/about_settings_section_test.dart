import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/app_logging.dart';
import 'package:kanaru/features/settings/about_settings_section.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/open_external.dart';
import 'package:kanaru/shared/widgets/kanaru_logo.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [openExternalProvider.overrideWithValue((_) async => true)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: Scaffold(body: _Page()),
    ),
  ),
);

void main() {
  final name = find.text('Kanaru');
  final version = find.text('Version $kanaruVersion');

  testWidgets('logo is 72 and not inside a list tile', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(KanaruLogo)), const Size(72, 72));
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(KanaruLogo),
      ),
      findsNothing,
    );
  });

  testWidgets('logo, name and version are centered and stacked', (
    tester,
  ) async {
    await _pump(tester);
    expect(name, findsOneWidget);
    expect(version, findsOneWidget);

    final center = tester.getCenter(find.byType(AboutSettingsSection)).dx;
    final logoX = tester.getCenter(find.byType(KanaruLogo)).dx;
    expect(logoX, closeTo(center, 0.5));
    expect(tester.getCenter(name).dx, closeTo(logoX, 0.5));
    expect(tester.getCenter(version).dx, closeTo(logoX, 0.5));

    final logoTop = tester.getTopLeft(find.byType(KanaruLogo)).dy;
    final nameTop = tester.getTopLeft(name).dy;
    final versionTop = tester.getTopLeft(version).dy;
    expect(logoTop, lessThan(nameTop));
    expect(nameTop, lessThan(versionTop));
    expect(
      tester.getBottomLeft(version).dy,
      lessThan(tester.getTopLeft(find.text('License')).dy),
    );
  });

  testWidgets('rows below the header keep their alignment', (tester) async {
    await _pump(tester);
    expect(
      tester.getTopLeft(find.text('License')).dx,
      tester.getTopLeft(find.text('Source code')).dx,
    );
  });

  testWidgets('screen readers get one merged node', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(RegExp('Kanaru\\nVersion')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('does not overflow on a narrow width', (tester) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    expect(tester.takeException(), isNull);
  });
}

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) =>
      ListView(children: const [AboutSettingsSection()]);
}
