import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/features/settings/lyrics_translation_setting_rows.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import 'translation_settings_harness.dart';

const _google = TranslationServiceId.google;

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

  group('translate plugins', () {
    const id = 'plugin-abc123def456';
    final plugin = TranslationServiceId.tryParse(id)!;

    List<Override> withPlugins(List<LyricsPluginRecord> records) => [
      lyricsPluginRecordsProvider.overrideWithValue(records),
      translatePluginRecordsProvider.overrideWithValue(
        AsyncValue.data(records),
      ),
    ];

    testWidgets('the picker lists Google and the plugin', (tester) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([translateRecord(id, name: 'Gemini')]),
      );

      // Two options keep the segmented button.
      expect(
        find.byType(SegmentedButton<TranslationServiceId>),
        findsOneWidget,
      );
      expect(find.text('Google'), findsOneWidget);
      // The label of the segment and the row of the installed plugin.
      expect(find.text('Gemini'), findsNWidgets(2));
      expect(find.text('v1'), findsOneWidget);
      expect(find.text('Get translation services'), findsOneWidget);
    });

    testWidgets('more than two services use a dropdown', (tester) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([
          translateRecord(id, name: 'Gemini'),
          translateRecord('plugin-zzzzzzzzzzzz', name: 'Other'),
        ]),
      );

      expect(find.byType(SegmentedButton<TranslationServiceId>), findsNothing);
      expect(find.byType(DropdownMenu<TranslationServiceId>), findsOneWidget);
    });

    testWidgets('a selected plugin that is gone shows Google, writes nothing', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(
        settings: AppSettings(
          translation: TranslationPrefs(
            service: plugin,
            noticeAcknowledged: {plugin},
          ),
        ),
      );
      await h.pump(tester, rows, overrides: withPlugins(const []));

      final picker = tester.widget<SegmentedButton<TranslationServiceId>>(
        find.byType(SegmentedButton<TranslationServiceId>),
      );
      expect(picker.selected, {TranslationServiceId.google});
      expect(h.prefs.service, plugin);
    });

    testWidgets('picking a plugin while translation is on asks first', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(
        settings: const AppSettings(
          translation: TranslationPrefs(
            show: true,
            noticeAcknowledged: {_google},
          ),
        ),
      );
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([
          translateRecord(id, name: 'Gemini', hosts: const ['gemini.example']),
        ]),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TranslationServiceId>),
          matching: find.text('Gemini'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Lyrics will be sent to the plugin Gemini'),
        findsOneWidget,
      );
      expect(find.text('gemini.example'), findsOneWidget);
      expect(h.prefs.service, _google);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.prefs.service, _google);
      expect(h.prefs.noticeAcknowledged, {_google});

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TranslationServiceId>),
          matching: find.text('Gemini'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(h.prefs.service, plugin);
      expect(h.prefs.noticeAcknowledged, {_google, plugin});
    });

    testWidgets('picking a plugin while translation is off needs no notice', (
      tester,
    ) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([translateRecord(id, name: 'Gemini')]),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<TranslationServiceId>),
          matching: find.text('Gemini'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(h.prefs.service, plugin);
      expect(h.prefs.show, isFalse);
    });

    testWidgets('a plugin named Google shows as Google (plugin)', (
      tester,
    ) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([translateRecord(id, name: 'Google')]),
      );

      expect(find.text('Google (plugin)'), findsWidgets);
    });

    for (final (label, state) in [
      ('loading', const AsyncValue<List<LyricsPluginRecord>>.loading()),
      (
        'unreadable',
        AsyncValue<List<LyricsPluginRecord>>.error('x', StackTrace.empty),
      ),
    ]) {
      testWidgets('records $label: stored plugin shown, picker disabled', (
        tester,
      ) async {
        final h = TranslationSettingsHarness(
          settings: AppSettings(
            translation: TranslationPrefs(
              service: plugin,
              noticeAcknowledged: {plugin},
            ),
          ),
        );
        await h.pump(
          tester,
          rows,
          overrides: [
            lyricsPluginRecordsProvider.overrideWithValue(const []),
            translatePluginRecordsProvider.overrideWithValue(state),
          ],
        );

        final picker = tester.widget<SegmentedButton<TranslationServiceId>>(
          find.byType(SegmentedButton<TranslationServiceId>),
        );
        expect(picker.selected, {plugin});
        expect(picker.onSelectionChanged, isNull);
        await tester.tap(find.text('Google'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(h.prefs.service, plugin);
      });
    }
  });
}
