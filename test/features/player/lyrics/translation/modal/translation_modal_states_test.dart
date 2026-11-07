import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_labels.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_action_bar.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

const _otherId = 'plugin-111111111111';
final _otherPlugin = TranslationServiceId.tryParse(_otherId)!;

class _NeedsConfig extends Fake implements LyricsPluginsController {
  @override
  Future<bool> needsConfig(String installId) async => true;
}

void main() {
  final info = fakeTranslationInfo();
  final onPrefs = TranslationPrefs(
    show: true,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin, _otherPlugin},
  );
  final twoPlugins = [
    translateRecord(testTranslatePluginId, name: 'Test Translate'),
    translateRecord(_otherId, name: 'Other'),
  ];
  const sampleLines = ['The last kiss', 'Tasted like cigarettes'];

  TranslationFailed failed(TranslationFailureKind kind) =>
      TranslationFailed(info, testTranslatePlugin, kind);

  Future<TranslationModalHarness> pumpState(
    WidgetTester tester,
    LyricsTranslationState state, {
    TranslationPrefs? settings,
    Locale locale = const Locale('en'),
  }) => pumpTranslationModal(
    tester,
    state: state,
    settings: settings ?? onPrefs,
    locale: locale,
    pluginOverrides: translatePluginOverrides(records: twoPlugins),
    overrides: [
      lyricsPluginsControllerProvider.overrideWithValue(_NeedsConfig()),
    ],
  );

  testWidgets('Loading shows Translating and Cancel turns translation off', (
    tester,
  ) async {
    final h = await pumpState(
      tester,
      TranslationLoading(info, testTranslatePlugin),
    );
    expect(find.text('Translating…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(h.prefs.show, isFalse);
  });

  testWidgets('Ready(refreshing) shows refreshing provenance and Cancel', (
    tester,
  ) async {
    final state = TranslationReady(
      info,
      testTranslatePlugin,
      'ja',
      sampleLines,
      false,
      refreshing: true,
    );
    final h = await pumpState(tester, state);
    expect(find.text('Retranslating; the old version stays'), findsOneWidget);
    expect(find.byIcon(AppIcons.refresh), findsNothing);
    expect(find.text('Retranslating…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(h.fake.cancelRetranslateCalls, 1);
  });

  testWidgets('Failed(badKey) opens plugin settings and hides Retry', (
    tester,
  ) async {
    final h = await pumpState(tester, failed(TranslationFailureKind.badKey));
    expect(find.text('Test Translate reported an error'), findsOneWidget);
    expect(
      find.text('The service rejected the API key. Check it in Settings.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Open settings'));
    await settleModal(tester);
    expect(find.byType(LyricsTranslationModal), findsNothing);
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(h.visitedRoutes, [translationPluginRoute(testTranslatePluginId)]);
  });

  testWidgets('Failed(network) offers Retry and Failed(needsConfig) config', (
    tester,
  ) async {
    final h = await pumpState(tester, failed(TranslationFailureKind.network));
    expect(find.text('Open settings'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(h.fake.retryCalls, 1);

    h.fake.emit(failed(TranslationFailureKind.needsConfig));
    await tester.pump();
    expect(find.text('Open config'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Ready(retranslateFailure) names selected service and retries', (
    tester,
  ) async {
    final state = TranslationReady(
      info,
      _otherPlugin,
      'ja',
      sampleLines,
      true,
      retranslateFailure: TranslationFailureKind.network,
    );
    final h = await pumpState(tester, state);
    expect(find.text('Test Translate reported an error'), findsOneWidget);
    expect(find.byType(TranslationActionBar), findsNothing);
    await tester.tap(find.text('Keep the old version'));
    await tester.pump();
    expect(h.fake.dismissRetranslateFailureCalls, 1);
    await tester.tap(find.text('Retry'));
    await settleModal(tester);
    expect(h.fake.retranslateCalls, 1);
    expect(find.byType(LyricsTranslationModal), findsNothing);
  });

  testWidgets('SameLanguage(retranslateFailure) shows the failure card', (
    tester,
  ) async {
    final h = await pumpState(
      tester,
      TranslationSameLanguage(
        info,
        _otherPlugin,
        fromOtherService: true,
        retranslateFailure: TranslationFailureKind.network,
      ),
    );
    expect(find.text('Test Translate reported an error'), findsOneWidget);
    expect(find.byType(TranslationActionBar), findsNothing);
    await tester.tap(find.text('Keep the old version'));
    await tester.pump();
    expect(h.fake.dismissRetranslateFailureCalls, 1);
    await tester.tap(find.text('Retry'));
    await settleModal(tester);
    expect(h.fake.retranslateCalls, 1);
  });

  testWidgets('SameLanguage shows note and lowercases Vietnamese name', (
    tester,
  ) async {
    await pumpState(tester, TranslationSameLanguage(info, testTranslatePlugin));
    expect(find.text('Lyrics are already in English'), findsOneWidget);
    expect(find.text('Retranslate'), findsNothing);

    final infoVi = fakeTranslationInfo(defaultCode: 'vi');
    await pumpState(
      tester,
      TranslationSameLanguage(infoVi, testTranslatePlugin),
      locale: const Locale('vi'),
    );
    expect(find.text('Lời bài hát đã là tiếng Việt'), findsOneWidget);
  });

  testWidgets(
    'SameLanguage from another service names it and offers Translate with',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        size: const Size(380, 800),
        state: TranslationSameLanguage(
          info,
          TranslationServiceId.tryParse('plugin-111111111111')!,
          fromOtherService: true,
        ),
        settings: onPrefs,
        pluginOverrides: translatePluginOverrides(
          records: [
            translateRecord(testTranslatePluginId, name: 'Test Translate'),
            translateRecord('plugin-111111111111', name: 'Other'),
          ],
        ),
      );
      expect(
        find.text('Lyrics are already in English\n(per Other)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Translate with Test Translate'));
      await settleModal(tester);
      expect(h.fake.retranslateCalls, 1);
    },
  );

  testWidgets('SameLanguage refreshing shows progress, Cancel cancels', (
    tester,
  ) async {
    final h = await pumpState(
      tester,
      TranslationSameLanguage(
        info,
        testTranslatePlugin,
        fromOtherService: true,
        refreshing: true,
      ),
    );
    expect(find.text('Retranslating…'), findsOneWidget);
    expect(find.text('Translate with Test Translate'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(h.fake.cancelRetranslateCalls, 1);
  });

  testWidgets(
    'modal stays open after picking a plugin and shows a scripted needs-config failure card',
    (tester) async {
      final h = await pumpState(
        tester,
        TranslationOff(info),
        settings: onPrefs.copyWith(service: _otherPlugin),
      );
      await tester.tap(find.byType(TranslationServiceSection));
      await settleModal(tester);
      await tester.tap(find.widgetWithText(SelectionRow, 'Test Translate'));
      await settleModal(tester);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);

      h.fake.emit(failed(TranslationFailureKind.needsConfig));
      await tester.pump();
      await tester.tap(find.text('Open config'));
      await settleModal(tester);
      expect(h.visitedRoutes, [translationPluginRoute(testTranslatePluginId)]);
    },
  );

  test('every failure kind has its own sentence in both languages', () {
    for (final locale in const [Locale('en'), Locale('vi')]) {
      final l10n = lookupAppLocalizations(locale);
      final set = {
        for (final k in TranslationFailureKind.values)
          translationFailureMessage(l10n, k),
      };
      expect(set.length, TranslationFailureKind.values.length);
      expect(set, isNot(contains('')));
    }
  });
}
