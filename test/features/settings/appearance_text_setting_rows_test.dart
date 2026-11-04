import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/custom_font_providers.dart';
import 'package:kanaru/core/fonts/custom_font_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/appearance_text_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'appearance_rows_harness.dart';

class _FixedCustomFontsNotifier extends CustomFontsNotifier {
  _FixedCustomFontsNotifier(this._items);
  final List<CustomFontItem> _items;

  @override
  List<CustomFontItem> build() => _items;
}

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

    testWidgets('shows custom font label when custom font is active', (
      tester,
    ) async {
      final customItem = CustomFontItem(
        id: 'custom_fira_code_12345678',
        label: 'Fira Code Custom',
        file: File('/tmp/fira.ttf'),
      );

      await pumpAppearanceRows(
        tester,
        rows,
        fontId: 'custom_fira_code_12345678',
        overrides: [
          customFontsProvider.overrideWith(
            () => _FixedCustomFontsNotifier([customItem]),
          ),
        ],
      );

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Font'),
          matching: find.text('Fira Code Custom'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to customFontFallbackLabel if font not in list', (
      tester,
    ) async {
      await pumpAppearanceRows(
        tester,
        rows,
        fontId: 'custom_fira_code_12345678',
        overrides: [
          customFontsProvider.overrideWith(
            () => _FixedCustomFontsNotifier([]),
          ),
        ],
      );

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Font'),
          matching: find.text('fira code'),
        ),
        findsOneWidget,
      );
    });
  });

  group('currentFontLabel', () {
    testWidgets('resolves correct labels for built-in, custom, and missing custom fonts', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final customList = [
        CustomFontItem(
          id: 'custom_comic_sans_11223344',
          label: 'Comic Sans MS Pro',
          file: File('/dummy/path.ttf'),
        ),
      ];

      expect(currentFontLabel(l10n, 'inter', customList), 'Inter');
      expect(currentFontLabel(l10n, 'system', customList), 'System');
      expect(
        currentFontLabel(l10n, 'custom_comic_sans_11223344', customList),
        'Comic Sans MS Pro',
      );
      expect(
        currentFontLabel(l10n, 'custom_unknown_font_aabbccdd', customList),
        'unknown font',
      );
    });
  });
}
