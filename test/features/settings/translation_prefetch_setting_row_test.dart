import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/translation_prefetch_setting_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_settings_harness.dart';

void main() {
  const row = TranslationPrefetchSettingRow();
  final plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;

  TranslationSettingsHarness withService({int prefetch = 0}) =>
      TranslationSettingsHarness(
        settings: AppSettings(
          translation: TranslationPrefs(
            service: plugin,
            noticeAcknowledged: {plugin},
            prefetchCount: prefetch,
          ),
        ),
      );

  /// The text shown in the dropdown's field (the menu items also carry labels).
  String shown(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownMenu<int>));
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, label).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('shows 0 as the playing song only', (tester) async {
    final h = withService();
    await h.pump(tester, row);
    expect(find.text('Translate ahead'), findsOneWidget);
    expect(shown(tester), 'Only the playing song');
  });

  testWidgets('going up from 0 asks first, OK saves it', (tester) async {
    final h = withService();
    await h.pump(tester, row);

    await pick(tester, 'Next 3 songs');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('will be sent to the translation'), findsOne);
    expect(h.prefs.prefetchCount, 0);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(h.prefs.prefetchCount, 3);
    expect(h.prefs.service, plugin);
  });

  testWidgets('Cancel keeps 0 and shows it again', (tester) async {
    final h = withService();
    await h.pump(tester, row);

    await pick(tester, 'Next song');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(h.prefs.prefetchCount, 0);
    expect(shown(tester), 'Only the playing song');
  });

  testWidgets('changing between non-zero values does not ask', (tester) async {
    final h = withService(prefetch: 3);
    await h.pump(tester, row);

    await pick(tester, 'Next 2 songs');
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.prefs.prefetchCount, 2);

    await pick(tester, 'Only the playing song');
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.prefs.prefetchCount, 0);
  });

  testWidgets('is locked without a default service', (tester) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    expect(
      tester.widget<DropdownMenu<int>>(find.byType(DropdownMenu<int>)).enabled,
      isFalse,
    );
  });

  testWidgets('speaks Vietnamese', (tester) async {
    final h = withService(prefetch: 2);
    await h.pump(tester, row, locale: const Locale('vi'));
    expect(find.text('Dịch trước'), findsOneWidget);
    expect(shown(tester), '2 bài tiếp theo');
  });
}
