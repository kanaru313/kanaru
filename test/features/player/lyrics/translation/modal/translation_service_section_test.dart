import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_badge.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

void main() {
  final onPrefs = TranslationPrefs(
    show: true,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin},
  );
  final offWithService = TranslationPrefs(
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin},
  );

  testWidgets('translation on: the service row is shown', (tester) async {
    await pumpTranslationModal(tester, settings: onPrefs);
    expect(find.text('Test Translate'), findsOneWidget);
    // A plain translate plugin has no AI badge and no tuning row.
    expect(find.byType(TranslationAiBadge), findsNothing);
    expect(find.text('AI tuning'), findsNothing);
  });

  testWidgets('selected service row draws that plugin\'s own icon', (
    tester,
  ) async {
    await pumpTranslationModal(tester, settings: onPrefs);
    final finder = find.descendant(
      of: find.byType(TranslationServiceSection),
      matching: find.byType(PluginIcon),
    );
    expect(
      tester.widget<PluginIcon>(finder).record?.installId,
      testTranslatePluginId,
    );
  });

  testWidgets('no service selected: error icon, no plugin icon', (
    tester,
  ) async {
    await pumpTranslationModal(tester, settings: const TranslationPrefs());
    expect(find.byIcon(AppIcons.errorOutline), findsOneWidget);
    expect(find.byType(PluginIcon), findsNothing);
  });

  testWidgets('translation off with a service: the section is hidden', (
    tester,
  ) async {
    await pumpTranslationModal(tester, settings: offWithService);
    expect(find.text('Test Translate'), findsNothing);
    expect(find.text('Not selected'), findsNothing);
    expect(find.text('No translation plugin'), findsNothing);
  });

  testWidgets('translation off without a service: the row says Not selected', (
    tester,
  ) async {
    await pumpTranslationModal(tester, settings: const TranslationPrefs());
    expect(find.text('Not selected'), findsOneWidget);
  });

  testWidgets('zero plugins and no service: the empty-plugins card shows', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: const TranslationPrefs(),
      pluginOverrides: translatePluginOverrides(records: const []),
    );
    expect(find.text('No translation plugin'), findsOneWidget);
    expect(find.text('Not selected'), findsNothing);
  });

  testWidgets('records loading, translation off, stored service: hidden', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: offWithService,
      pluginOverrides: [
        translatePluginRecordsProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    expect(find.text('Loading translation plugins…'), findsNothing);
  });

  for (final (name, value) in <(String, AsyncValue<List<LyricsPluginRecord>>)>[
    ('loading', const AsyncLoading()),
    ('unreadable', AsyncError(Exception('broken'), StackTrace.empty)),
  ]) {
    testWidgets('records $name, translation on: row is disabled with a hint', (
      tester,
    ) async {
      await pumpTranslationModal(
        tester,
        settings: onPrefs,
        pluginOverrides: [
          translatePluginRecordsProvider.overrideWithValue(value),
        ],
      );
      expect(find.text('Loading translation plugins…'), findsOneWidget);
      await tester.tap(find.text('Loading translation plugins…'));
      await settleModal(tester);
      expect(find.text('Translation service'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  LyricsTranslationState stateWith(
    TranslationScope scope, {
    TranslationServiceId? service,
  }) => TranslationOff(
    fakeTranslationInfo(
      choice: TranslationChoice(
        service: service,
        scope: scope,
        tune: const {},
        defaultService: testTranslatePlugin,
      ),
    ),
  );

  testWidgets('subtitle names a song\'s own choice and its default', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: onPrefs,
      state: stateWith(TranslationScope.song, service: testTranslatePlugin),
    );
    expect(
      find.text('Only this song · default: Test Translate'),
      findsOneWidget,
    );
  });

  testWidgets('subtitle for a song that follows the default', (tester) async {
    await pumpTranslationModal(
      tester,
      settings: onPrefs,
      state: stateWith(TranslationScope.all, service: testTranslatePlugin),
    );
    expect(find.text('Default service for every song'), findsOneWidget);
  });

  testWidgets('unset and loading subtitles win over the scope subtitle', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: const TranslationPrefs(),
      state: stateWith(TranslationScope.all),
    );
    expect(find.text('Lyrics are sent only after you choose'), findsOneWidget);
    expect(find.text('Default service for every song'), findsNothing);
  });

  testWidgets('loading plugin records show the loading subtitle only', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: onPrefs,
      state: stateWith(TranslationScope.all, service: testTranslatePlugin),
      pluginOverrides: const [],
      overrides: [
        translatePluginRecordsProvider.overrideWithValue(
          const AsyncLoading<List<LyricsPluginRecord>>(),
        ),
      ],
    );
    expect(find.text('Loading translation plugins…'), findsOneWidget);
    expect(find.text('Default service for every song'), findsNothing);
  });
}
