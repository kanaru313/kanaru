import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

// The song has its own service ("Own"); the default is "Test Translate", and
// the version on screen is the default's.
const _ownId = 'plugin-111111111111';
final _own = TranslationServiceId.tryParse(_ownId)!;

void main() {
  final prefs = TranslationPrefs(
    show: true,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin, _own},
  );
  final records = [
    translateRecord(testTranslatePluginId, name: 'Test Translate'),
    translateRecord(_ownId, name: 'Own'),
  ];
  final songChoice = fakeTranslationChoice(
    _own,
    scope: TranslationScope.song,
    defaultService: testTranslatePlugin,
  );
  const lines = ['The last kiss', 'Tasted like cigarettes'];

  Future<TranslationModalHarness> pump(
    WidgetTester tester,
    LyricsTranslationState state,
  ) => pumpTranslationModal(
    tester,
    state: state,
    settings: prefs,
    pluginOverrides: translatePluginOverrides(records: records),
  );

  testWidgets('the service row and the bar name the song\'s own service', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationReady(
        fakeTranslationInfo(choice: songChoice),
        testTranslatePlugin,
        'ja',
        lines,
        true,
      ),
    );

    // Row of the service in use: the song's, not the default.
    expect(
      find.descendant(
        of: find.byType(TranslationServiceSection),
        matching: find.text('Own'),
      ),
      findsOneWidget,
    );
    expect(find.text('Translate with Own'), findsOneWidget);
    expect(find.text('Translate with Test Translate'), findsNothing);
  });

  testWidgets('a retranslate failure is named after the song\'s service', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationReady(
        fakeTranslationInfo(choice: songChoice),
        testTranslatePlugin,
        'ja',
        lines,
        true,
        retranslateFailure: TranslationFailureKind.badKey,
      ),
    );

    expect(find.textContaining('Own'), findsWidgets);
    expect(find.text('Translate with Test Translate'), findsNothing);
  });

  testWidgets('the switch is off when the song\'s service needs the notice', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      state: TranslationNeedsNotice(
        fakeTranslationInfo(choice: songChoice),
        _own,
      ),
      settings: TranslationPrefs(
        show: true,
        service: testTranslatePlugin,
        noticeAcknowledged: {testTranslatePlugin},
      ),
      pluginOverrides: translatePluginOverrides(records: records),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('without a song choice the default is shown', (tester) async {
    await pump(
      tester,
      TranslationReady(
        fakeTranslationInfo(choice: fakeTranslationChoice(testTranslatePlugin)),
        _own,
        'ja',
        lines,
        true,
      ),
    );

    expect(find.text('Translate with Test Translate'), findsOneWidget);
  });
}
