import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/features/settings/settings_number_presets.dart';
import 'package:kanaru/features/settings/translation_cache_setting_row.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_settings_harness.dart';

void main() {
  const row = TranslationCacheSettingRow();
  final clearButton = find.widgetWithText(FilledButton, 'Clear');

  Future<void> seed(
    WidgetTester tester,
    TranslationSettingsHarness h,
    List<String> hashes,
  ) => tester.runAsync(
    // One transaction: with the stats stream watching, separate writes would
    // queue behind its re-read, which only the test clock can run.
    () => h.db.transaction(() async {
      for (final hash in hashes) {
        await h.db.saveLyricTranslation(
          LyricTranslationsCompanion.insert(
            contentHash: hash,
            provider: 'google',
            targetLang: 'vi',
            // Nine bytes each.
            linesJson: '{"a":"b"}',
            createdAt: 1,
          ),
        );
      }
      await h.db.setSongTranslationTarget('h1', 'ja');
    }),
  );

  Future<int> rows(WidgetTester tester, TranslationSettingsHarness h) async =>
      (await tester.runAsync(() => h.db.select(h.db.lyricTranslations).get()))!
          .length;

  Future<int> prefRows(
    WidgetTester tester,
    TranslationSettingsHarness h,
  ) async => (await tester.runAsync(
    () => h.db.select(h.db.lyricTranslationPrefs).get(),
  ))!.length;

  testWidgets('shows the count and size of the saved translations live', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    expect(find.text('No saved translations'), findsOneWidget);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

    await seed(tester, h, ['h1', 'h2']);
    await pumpIo(
      tester,
      done: () => find.text('2 songs · 18 B').evaluate().isNotEmpty,
    );
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);

    await seed(tester, h, ['h3']);
    await pumpIo(
      tester,
      done: () => find.text('3 songs · 27 B').evaluate().isNotEmpty,
    );
  });

  testWidgets('one song reads in the singular', (tester) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    await seed(tester, h, ['h1']);
    await pumpIo(
      tester,
      done: () => find.text('1 song · 9 B').evaluate().isNotEmpty,
    );
  });

  testWidgets('clearing needs a confirmation and keeps the language picks', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, row);
    await seed(tester, h, ['h1', 'h2']);
    await pumpIo(tester, done: () => clearButton.evaluate().isNotEmpty);
    await pumpIo(
      tester,
      done: () => tester.widget<FilledButton>(clearButton).onPressed != null,
    );

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('Clear saved translations?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpIo(tester);
    expect(await rows(tester, h), 2);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Clear'),
      ),
    );
    await pumpIo(
      tester,
      done: () =>
          find.text('Cleared 2 saved translations').evaluate().isNotEmpty,
    );

    await tester.pumpAndSettle();

    expect(await rows(tester, h), 0);
    expect(await prefRows(tester, h), 1);
    expect(find.text('No saved translations'), findsOneWidget);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
  });

  testWidgets('without a library the button is off', (tester) async {
    final h = TranslationSettingsHarness(hasDatabase: false);
    await h.pump(tester, row);

    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    expect(find.text('No saved translations'), findsOneWidget);
  });

  test('sizes read in bytes, KB and MB', () {
    final l10n = AppLocalizationsEn();
    expect(formatBytes(l10n, 0), '0 B');
    expect(formatBytes(l10n, 1023), '1023 B');
    expect(formatBytes(l10n, 1024), '1 KB');
    expect(formatBytes(l10n, 150 * 1024), '150 KB');
    expect(formatBytes(l10n, 1536 * 1024), '1.5 MB');
  });
}
