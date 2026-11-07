import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_modal_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:kanaru/shared/widgets/picker_field_button.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

void main() {
  bool rowSelected(WidgetTester tester, String label) => tester
      .widget<SelectionRow>(find.widgetWithText(SelectionRow, label))
      .selected;

  Future<void> tapSwitch(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await settleModal(tester);
  }

  Future<void> openTarget(WidgetTester tester) async {
    await tester.tap(find.byType(PickerFieldButton));
    await settleModal(tester);
  }

  testWidgets('switch turns translation on and off and keeps the modal open', (
    tester,
  ) async {
    final h = await pumpTranslationModal(tester);

    await tapSwitch(tester);
    expect(h.prefs.show, isTrue);
    expect(find.byType(LyricsTranslationModal), findsOneWidget);

    await tapSwitch(tester);
    expect(h.prefs.show, isFalse);
    expect(find.byType(LyricsTranslationModal), findsOneWidget);
  });

  testWidgets(
    'first switch-on asks network notice; Cancel keeps it off; Continue accepts and second time is silent',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        settings: TranslationPrefs(service: testTranslatePlugin),
      );

      await tapSwitch(tester);
      expect(
        find.text('Lyrics will be sent to the plugin Test Translate'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await settleModal(tester);
      expect(h.prefs.show, isFalse);
      expect(h.prefs.noticeAcknowledged, isEmpty);

      await tapSwitch(tester);
      await tester.tap(find.text('Continue'));
      await settleModal(tester);
      expect(h.prefs.show, isTrue);
      expect(h.prefs.noticeAcknowledged, {testTranslatePlugin});

      await tapSwitch(tester);
      await tapSwitch(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.prefs.show, isTrue);
    },
  );

  testWidgets('uninstalled plugin: switch turns translation off silently', (
    tester,
  ) async {
    final gone = TranslationServiceId.tryParse('plugin-gone00000001')!;
    final h = await pumpTranslationModal(
      tester,
      settings: TranslationPrefs(
        show: true,
        service: gone,
        noticeAcknowledged: {gone},
      ),
    );
    await tapSwitch(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.prefs.show, isFalse);
  });

  testWidgets('loading plugin records: switch shows on and turns it off', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      settings: TranslationPrefs(
        show: true,
        service: testTranslatePlugin,
        noticeAcknowledged: {testTranslatePlugin},
      ),
      pluginOverrides: [
        translatePluginRecordsProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tapSwitch(tester);
    expect(h.prefs.show, isFalse);
  });

  testWidgets('needs-notice state shows the switch off', (tester) async {
    await pumpTranslationModal(
      tester,
      state: TranslationNeedsNotice(
        fakeTranslationInfo(choice: fakeTranslationChoice(testTranslatePlugin)),
        testTranslatePlugin,
      ),
      settings: TranslationPrefs(show: true, service: testTranslatePlugin),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('unset service: switch opens service picker with no checkmark', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      settings: const TranslationPrefs(),
    );
    expect(find.text('Not selected'), findsOneWidget);
    await tapSwitch(tester);

    expect(find.text('Translation service'), findsOneWidget);
    expect(rowSelected(tester, 'Test Translate'), isFalse);
    expect(h.prefs.show, isFalse);
  });

  testWidgets('zero plugins: switch is disabled and card opens plugin store', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      settings: const TranslationPrefs(),
      pluginOverrides: translatePluginOverrides(records: const []),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('No translation plugin'), findsOneWidget);
    await tester.tap(find.text('Open plugin store'));
    await settleModal(tester);

    expect(find.byType(LyricsTranslationModal), findsNothing);
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(h.visitedRoutes, [translationPluginsRoute]);
  });

  testWidgets(
    'target picker searches, selects per-song override or Default, and Escape closes only the child modal',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        state: TranslationOff(fakeTranslationInfo(songOverride: 'ja')),
      );
      final before = h.prefs;
      expect(find.text('Detected automatically'), findsOneWidget);

      await openTarget(tester);
      expect(find.text('Translate to'), findsOneWidget);
      expect(find.text('Search 42 items'), findsOneWidget);
      expect(find.byType(TranslationModalHeader), findsOneWidget);
      expect(rowSelected(tester, 'Japanese'), isTrue);
      expect(rowSelected(tester, 'Default (English)'), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleModal(tester);
      expect(find.text('Translate to'), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);

      await openTarget(tester);
      await tester.enterText(find.byType(TextField), 'Chinese');
      await settleModal(tester);
      expect(find.text('Chinese (Simplified)'), findsOneWidget);
      expect(find.text('Chinese (Traditional)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Vietnamese');
      await settleModal(tester);
      await tester.tap(find.widgetWithText(SelectionRow, 'Vietnamese'));
      await settleModal(tester);

      await openTarget(tester);
      await tester.tap(find.text('Default (English)'));
      await settleModal(tester);
      expect(h.fake.songTargets, ['vi', null]);
      expect(h.prefs, before);
    },
  );
}
