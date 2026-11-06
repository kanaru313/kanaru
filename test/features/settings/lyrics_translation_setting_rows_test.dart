import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/features/settings/lyrics_translation_setting_rows.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import 'translation_settings_harness.dart';

class _NeedsConfig extends Fake implements LyricsPluginsController {
  _NeedsConfig(this.answer);

  final bool answer;

  @override
  Future<bool> needsConfig(String installId) async => answer;
}

void main() {
  const rows = LyricsTranslationSettingRows();
  const id = 'plugin-abc123def456';
  const otherId = 'plugin-zzzzzzzzzzzz';
  final plugin = TranslationServiceId.tryParse(id)!;
  final other = TranslationServiceId.tryParse(otherId)!;

  List<Override> withPlugins(List<LyricsPluginRecord> records) => [
    lyricsPluginRecordsProvider.overrideWithValue(records),
    translatePluginRecordsProvider.overrideWithValue(AsyncValue.data(records)),
  ];

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

  Future<void> pickService(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownMenu<TranslationServiceId>));
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, label).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('Not selected is shown by default and needs no key', (
    tester,
  ) async {
    final h = TranslationSettingsHarness();
    await h.pump(tester, rows);

    expect(find.text('Not selected'), findsOneWidget);
    expect(find.textContaining('API key'), findsNothing);
    expect(h.store.reads, 0);
  });

  testWidgets('picking the selected service changes nothing', (tester) async {
    final h = TranslationSettingsHarness(
      settings: AppSettings(translation: TranslationPrefs(service: plugin)),
    );
    await h.pump(
      tester,
      rows,
      overrides: withPlugins([translateRecord(id, name: 'Gemini')]),
    );

    await pickService(tester, 'Gemini');
    await pumpIo(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(h.prefs.service, plugin);
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
    testWidgets('the picker uses a dropdown and lists the plugin', (
      tester,
    ) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([translateRecord(id, name: 'Gemini')]),
      );

      expect(find.byType(SegmentedButton<TranslationServiceId>), findsNothing);
      expect(find.byType(DropdownMenu<TranslationServiceId>), findsOneWidget);
      expect(find.text('Not selected'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
      expect(find.text('Get translation services'), findsOneWidget);

      await tester.tap(find.byType(DropdownMenu<TranslationServiceId>));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Gemini'), findsWidgets);
    });

    testWidgets('multiple services use a dropdown', (tester) async {
      final h = TranslationSettingsHarness();
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([
          translateRecord(id, name: 'Gemini'),
          translateRecord(otherId, name: 'Other'),
        ]),
      );

      expect(find.byType(SegmentedButton<TranslationServiceId>), findsNothing);
      expect(find.byType(DropdownMenu<TranslationServiceId>), findsOneWidget);
    });

    testWidgets(
      'a selected plugin that is gone shows Not selected, writes nothing',
      (tester) async {
        final h = TranslationSettingsHarness(
          settings: AppSettings(
            translation: TranslationPrefs(
              service: plugin,
              noticeAcknowledged: {plugin},
            ),
          ),
        );
        await h.pump(tester, rows, overrides: withPlugins(const []));

        final picker = tester.widget<DropdownMenu<TranslationServiceId>>(
          find.byType(DropdownMenu<TranslationServiceId>),
        );
        expect(picker.initialSelection, isNull);
        expect(find.text('Not selected'), findsOneWidget);
        expect(h.prefs.service, plugin);
      },
    );

    testWidgets(
      'plugin to null after sweep shows Not selected, not the old name',
      (tester) async {
        final h = TranslationSettingsHarness(
          settings: AppSettings(
            translation: TranslationPrefs(
              show: true,
              service: plugin,
              noticeAcknowledged: {plugin},
            ),
          ),
        );
        await h.pump(
          tester,
          rows,
          overrides: withPlugins([translateRecord(id, name: 'Gemini')]),
        );

        final fieldBefore = tester.widget<TextField>(
          find.descendant(
            of: find.byType(DropdownMenu<TranslationServiceId>),
            matching: find.byType(TextField),
          ),
        );
        expect(fieldBefore.controller?.text, 'Gemini');

        h.container
            .read(settingsProvider.notifier)
            .dropUninstalledTranslationServices(const {});
        await tester.pumpAndSettle();

        final fieldAfter = tester.widget<TextField>(
          find.descendant(
            of: find.byType(DropdownMenu<TranslationServiceId>),
            matching: find.byType(TextField),
          ),
        );
        expect(fieldAfter.controller?.text, isEmpty);
        expect(find.text('Not selected'), findsOneWidget);
      },
    );

    for (final needs in [true, false]) {
      testWidgets(
        'picking a plugin ${needs ? 'that needs' : 'that does not need'} '
        'config ${needs ? 'reports it, and keeps it selected' : 'reports nothing'}',
        (tester) async {
          final h = TranslationSettingsHarness(
            settings: AppSettings(
              translation: TranslationPrefs(noticeAcknowledged: {plugin}),
            ),
          );
          await h.pump(
            tester,
            rows,
            overrides: [
              ...withPlugins([translateRecord(id, name: 'Gemini')]),
              lyricsPluginsControllerProvider.overrideWithValue(
                _NeedsConfig(needs),
              ),
            ],
          );

          await pickService(tester, 'Gemini');

          final notice = h.container.read(pluginNeedsConfigNoticesProvider);
          expect(h.prefs.service, plugin);
          expect(h.prefs.show, isTrue);
          if (needs) {
            expect(notice?.installId, id);
            expect(notice?.name, 'Gemini');
          } else {
            expect(notice, isNull);
          }
        },
      );
    }

    testWidgets('Cancel on the notice reports nothing', (tester) async {
      final h = TranslationSettingsHarness(
        settings: AppSettings(
          translation: TranslationPrefs(
            show: true,
            service: other,
            noticeAcknowledged: {other},
          ),
        ),
      );
      await h.pump(
        tester,
        rows,
        overrides: [
          ...withPlugins([
            translateRecord(id, name: 'Gemini'),
            translateRecord(otherId, name: 'Other'),
          ]),
          lyricsPluginsControllerProvider.overrideWithValue(_NeedsConfig(true)),
        ],
      );

      await pickService(tester, 'Gemini');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(h.prefs.service, other);
      expect(h.container.read(pluginNeedsConfigNoticesProvider), isNull);
    });

    testWidgets('picking a plugin while translation is on asks first', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(
        settings: AppSettings(
          translation: TranslationPrefs(
            show: true,
            service: other,
            noticeAcknowledged: {other},
          ),
        ),
      );
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([
          translateRecord(id, name: 'Gemini', hosts: const ['gemini.example']),
          translateRecord(otherId, name: 'Other'),
        ]),
      );

      await pickService(tester, 'Gemini');

      expect(
        find.text('Lyrics will be sent to the plugin Gemini'),
        findsOneWidget,
      );
      expect(find.text('gemini.example'), findsOneWidget);
      expect(h.prefs.service, other);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.prefs.service, other);
      expect(h.prefs.noticeAcknowledged, {other});

      await pickService(tester, 'Gemini');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(h.prefs.service, plugin);
      expect(h.prefs.noticeAcknowledged, {other, plugin});
    });

    testWidgets('switching plugins while translation is off needs no notice', (
      tester,
    ) async {
      final h = TranslationSettingsHarness(
        settings: AppSettings(translation: TranslationPrefs(service: other)),
      );
      await h.pump(
        tester,
        rows,
        overrides: withPlugins([
          translateRecord(id, name: 'Gemini'),
          translateRecord(otherId, name: 'Other'),
        ]),
      );

      await pickService(tester, 'Gemini');

      expect(find.byType(AlertDialog), findsNothing);
      expect(h.prefs.service, plugin);
      expect(h.prefs.show, isFalse);
    });

    testWidgets(
      'picking a plugin from null asks the notice and turns translation on; Cancel leaves it null',
      (tester) async {
        final h = TranslationSettingsHarness();
        await h.pump(
          tester,
          rows,
          overrides: withPlugins([
            translateRecord(
              id,
              name: 'Gemini',
              hosts: const ['gemini.example'],
            ),
          ]),
        );

        await pickService(tester, 'Gemini');
        expect(
          find.text('Lyrics will be sent to the plugin Gemini'),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(h.prefs.service, isNull);
        expect(h.prefs.show, isFalse);

        await pickService(tester, 'Gemini');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(h.prefs.service, plugin);
        expect(h.prefs.show, isTrue);
        expect(h.prefs.noticeAcknowledged, {plugin});
      },
    );

    testWidgets(
      '0 plugins: the service dropdown is disabled and shows Not selected',
      (tester) async {
        final h = TranslationSettingsHarness();
        await h.pump(tester, rows, overrides: withPlugins(const []));

        final picker = tester.widget<DropdownMenu<TranslationServiceId>>(
          find.byType(DropdownMenu<TranslationServiceId>),
        );
        expect(picker.enabled, isFalse);
        expect(picker.initialSelection, isNull);
        expect(find.text('Not selected'), findsOneWidget);
      },
    );

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

        final picker = tester.widget<DropdownMenu<TranslationServiceId>>(
          find.byType(DropdownMenu<TranslationServiceId>),
        );
        expect(picker.initialSelection, plugin);
        expect(picker.enabled, isFalse);
        await tester.tap(
          find.byType(DropdownMenu<TranslationServiceId>),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(h.prefs.service, plugin);
      });
    }
  });
}
