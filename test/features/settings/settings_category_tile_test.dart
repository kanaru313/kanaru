import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/settings_category_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onTap,
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsCategoryTile(
          icon: AppIcons.settingsAppearance,
          title: 'Appearance',
          description: 'Theme, font, language, sidebar and a long tail',
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the icon, title, description and a chevron', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(AppIcons.settingsAppearance), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(
      find.text('Theme, font, language, sidebar and a long tail'),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
  });

  testWidgets('tapping calls onTap once', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);

    await tester.tap(find.byType(SettingsCategoryTile));
    expect(taps, 1);
  });

  testWidgets('is at least 72 px tall', (tester) async {
    await _pump(tester);

    expect(
      tester.getSize(find.byType(ListTile)).height,
      greaterThanOrEqualTo(72),
    );
  });

  testWidgets('does not overflow at 320 px with text scale 2', (tester) async {
    await _pump(tester, size: const Size(320, 600), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(SettingsCategoryTile)).right,
      lessThanOrEqualTo(320),
    );
  });
}
