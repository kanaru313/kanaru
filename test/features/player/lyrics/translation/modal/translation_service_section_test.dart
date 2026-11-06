import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
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
}
