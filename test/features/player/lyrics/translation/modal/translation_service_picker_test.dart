import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_modal_navigation.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

const _id = 'plugin-abc123def456';
const _otherId = 'plugin-111111111111';

class _NeedsConfig extends Fake implements LyricsPluginsController {
  _NeedsConfig(this.answer);
  final bool answer;

  @override
  Future<bool> needsConfig(String installId) async => answer;
}

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;
  final other = TranslationServiceId.tryParse(_otherId)!;

  Future<TranslationModalHarness> pump(
    WidgetTester tester, {
    required TranslationPrefs settings,
    AsyncValue<List<LyricsPluginRecord>>? recordsState,
    bool openPicker = true,
    bool needsConfig = false,
  }) async {
    final live = [
      translateRecord(_id, name: 'Gemini'),
      translateRecord(_otherId, name: 'Other'),
    ];
    final h = await pumpTranslationModal(
      tester,
      settings: settings,
      pluginOverrides: const [],
      overrides: [
        lyricsPluginRecordsProvider.overrideWithValue(live),
        lyricsPluginsControllerProvider.overrideWithValue(
          _NeedsConfig(needsConfig),
        ),
        translatePluginRecordsProvider.overrideWithValue(
          recordsState ?? AsyncValue.data(live),
        ),
      ],
    );
    if (openPicker) {
      await tester.tap(find.byType(TranslationServiceSection));
      await settleModal(tester);
    }
    return h;
  }

  Finder row(String name) => find.widgetWithText(SelectionRow, name);
  bool isChecked(WidgetTester tester, String name) =>
      tester.widget<SelectionRow>(row(name)).selected;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settleModal(tester);
  }

  Future<void> openServiceRow(WidgetTester tester) async {
    await tester.tap(find.byType(TranslationServiceSection));
    await settleModal(tester);
  }

  /// Switches the open picker to the default-service scope.
  Future<void> tapAllSongs(WidgetTester tester) async {
    await tester.tap(find.text('All songs'));
    await tester.pump();
  }

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(row(name));
    await settleModal(tester);
  }

  testWidgets('lists live plugins, checks selected, and opens plugin store', (
    tester,
  ) async {
    final h = await pump(
      tester,
      settings: TranslationPrefs(
        show: true,
        service: other,
        noticeAcknowledged: {other},
      ),
    );

    expect(isChecked(tester, 'Other'), isTrue);
    expect(isChecked(tester, 'Gemini'), isFalse);
    expect(
      find.text('Translations saved on this device are used first.'),
      findsOneWidget,
    );

    await tapRow(tester, 'Other');
    expect(find.text('Translation service'), findsNothing);
    expect(find.byType(LyricsTranslationModal), findsOneWidget);

    await openServiceRow(tester);
    await tapText(tester, 'Get more translation plugins');
    expect(find.byType(LyricsTranslationModal), findsNothing);
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(h.visitedRoutes, [translationPluginsRoute]);
  });

  testWidgets(
    'unaccepted plugin asks the notice above the picker; accepted picks',
    (tester) async {
      final h = await pump(
        tester,
        settings: TranslationPrefs(
          show: true,
          service: other,
          noticeAcknowledged: {other},
        ),
      );

      await tapAllSongs(tester);
      await tapRow(tester, 'Gemini');
      expect(find.text('Translation service'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tapText(tester, 'Cancel');
      expect(h.prefs.service, other);
      expect(find.text('Translation service'), findsOneWidget);

      await tapRow(tester, 'Gemini');
      await tapText(tester, 'Continue');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Translation service'), findsNothing);
      expect(h.prefs.service, plugin);
      expect(h.prefs.noticeAcknowledged, {other, plugin});

      await openServiceRow(tester);
      await tapAllSongs(tester);
      await tapRow(tester, 'Other');
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.prefs.service, other);
      expect(h.fake.retranslateCalls, 0);
    },
  );

  testWidgets('picking from null asks notice and reports needs-config', (
    tester,
  ) async {
    final h = await pump(
      tester,
      settings: const TranslationPrefs(),
      needsConfig: true,
    );

    await tapRow(tester, 'Gemini');
    await tapText(tester, 'Cancel');
    expect(h.prefs.service, isNull);
    expect(h.prefs.show, isFalse);
    expect(h.container.read(pluginNeedsConfigNoticesProvider), isNull);

    await tapRow(tester, 'Gemini');
    await tapText(tester, 'Continue');
    expect(h.prefs.service, plugin);
    expect(h.prefs.show, isTrue);
    expect(h.container.read(pluginNeedsConfigNoticesProvider)?.installId, _id);
  });

  testWidgets('closing the modal stack also closes the notice and picker', (
    tester,
  ) async {
    await pump(
      tester,
      settings: TranslationPrefs(
        show: true,
        service: other,
        noticeAcknowledged: {other},
      ),
    );
    await tapRow(tester, 'Gemini');
    expect(find.byType(AlertDialog), findsOneWidget);

    closeTranslationModalStack(
      tester.element(find.byType(LyricsTranslationModal)),
    );
    await settleModal(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Translation service'), findsNothing);
    expect(find.byType(LyricsTranslationModal), findsNothing);
  });

  testWidgets('each plugin row shows that plugin\'s icon', (tester) async {
    await pump(tester, settings: const TranslationPrefs());
    for (final entry in {'Gemini': _id, 'Other': _otherId}.entries) {
      final icon = find.descendant(
        of: row(entry.key),
        matching: find.byType(PluginIcon),
      );
      expect(icon, findsOneWidget);
      expect(tester.widget<PluginIcon>(icon).record?.installId, entry.value);
    }
  });

  testWidgets('uninstalled plugin shows Not selected and no checkmark', (
    tester,
  ) async {
    await pump(
      tester,
      settings: TranslationPrefs(
        service: TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!,
      ),
      openPicker: false,
    );
    expect(find.text('Not selected'), findsOneWidget);
    await openServiceRow(tester);
    expect(isChecked(tester, 'Gemini'), isFalse);
    expect(isChecked(tester, 'Other'), isFalse);
  });
}
