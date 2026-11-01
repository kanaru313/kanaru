import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/features/settings/lyrics_translation_setting_rows.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_settings_harness.dart';

const _google = LyricsTranslationService.google;

void main() {
  const rows = LyricsTranslationSettingRows();

  Future<void> pickLanguage(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownMenu<({String? code})>));
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, label).last;
    // The open menu starts at the current choice; the item may be above it.
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('Google is the only service and needs no key', (tester) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, rows);

    expect(find.text('Google'), findsOneWidget);
    expect(find.textContaining('API key'), findsNothing);
    expect(h.store.reads, 0);
  });

  testWidgets('picking the selected service changes nothing', (tester) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, rows);

    await tester.tap(find.text('Google'));
    await pumpIo(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(h.prefs.service, _google);
  });

  testWidgets('the default language follows the app or is picked', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, rows);
    expect(find.text('Follow app language (English)'), findsWidgets);
    expect(h.prefs.targetLanguage, isNull);

    await pickLanguage(tester, 'Japanese');
    expect(h.prefs.targetLanguage, 'ja');

    await pickLanguage(tester, 'Follow app language (English)');
    expect(h.prefs.targetLanguage, isNull);
  });

  testWidgets('the follow choice names the Vietnamese app language', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, rows, locale: const Locale('vi'));

    expect(
      find.textContaining('Theo ngôn ngữ ứng dụng (Tiếng Việt)'),
      findsWidgets,
    );
  });
}
