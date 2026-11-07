import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_found_body.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_placeholder.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_action_bar.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

const _otherId = 'plugin-111111111111';
final _otherPlugin = TranslationServiceId.tryParse(_otherId)!;

void main() {
  final onPrefs = TranslationPrefs(
    show: true,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin},
  );
  final twoPlugins = [
    translateRecord(testTranslatePluginId, name: 'Test Translate'),
    translateRecord(_otherId, name: 'Other'),
  ];

  TranslationReady readyState({
    bool fromOtherService = false,
    bool refreshing = false,
  }) => TranslationReady(
    fakeTranslationInfo(),
    fromOtherService ? _otherPlugin : testTranslatePlugin,
    'ja',
    const ['The last kiss', 'Tasted like cigarettes'],
    fromOtherService,
    refreshing: refreshing,
  );

  bool? routeWasCurrent;

  testWidgets(
    'action bar shows for other service in 380px sheet and retranslates',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        size: const Size(380, 800),
        state: readyState(fromOtherService: true),
        settings: onPrefs,
        pluginOverrides: translatePluginOverrides(records: twoPlugins),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Saved version from Other'), findsOneWidget);
      expect(find.byIcon(AppIcons.refresh), findsNothing);
      expect(find.byType(TranslationActionBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(TranslationActionBar),
        ),
        findsNothing,
      );
      expect(find.text('Showing the version from Other'), findsOneWidget);
      expect(find.text('Translate with Test Translate'), findsOneWidget);

      final route = ModalRoute.of(
        tester.element(find.byType(LyricsTranslationModal)),
      )!;
      h.fake.onRetranslate = () => routeWasCurrent = route.isCurrent;
      await tester.tap(find.text('Translate with Test Translate'));
      await settleModal(tester);
      expect(h.fake.retranslateCalls, 1);
      expect(routeWasCurrent, isTrue, reason: 'retranslate runs before pop');
      expect(find.byType(LyricsTranslationModal), findsNothing);
    },
  );

  testWidgets('action bar is hidden for current service and while refreshing', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      state: readyState(),
      settings: onPrefs,
      pluginOverrides: translatePluginOverrides(records: twoPlugins),
    );
    expect(find.byType(TranslationActionBar), findsNothing);

    h.fake.emit(readyState(fromOtherService: true, refreshing: true));
    await tester.pump();
    expect(find.byType(TranslationActionBar), findsNothing);
  });

  testWidgets(
    'retranslate button closes modal at once and shows snackbar when saved',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        state: readyState(),
        settings: onPrefs,
      );
      final completer = Completer<TranslationJobStatus?>();
      h.fake.retranslateCompleter = completer;

      await tester.tap(find.byTooltip('Retranslate'));
      await settleModal(tester);
      expect(h.fake.retranslateCalls, 1);
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      completer.complete(const TranslationJobStatus.saved(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Retranslated with Test Translate'), findsOneWidget);
    },
  );

  testWidgets('the snackbar names the song\'s own service, not the default', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      state: TranslationReady(
        fakeTranslationInfo(
          choice: fakeTranslationChoice(
            _otherPlugin,
            scope: TranslationScope.song,
            defaultService: testTranslatePlugin,
          ),
        ),
        _otherPlugin,
        'ja',
        const ['The last kiss', 'Tasted like cigarettes'],
        false,
      ),
      settings: onPrefs,
      pluginOverrides: translatePluginOverrides(records: twoPlugins),
    );
    final completer = Completer<TranslationJobStatus?>();
    h.fake.retranslateCompleter = completer;

    await tester.tap(find.byTooltip('Retranslate'));
    await settleModal(tester);
    completer.complete(const TranslationJobStatus.saved(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Retranslated with Other'), findsOneWidget);
    expect(find.text('Retranslated with Test Translate'), findsNothing);
  });

  testWidgets('failed background retranslate shows no snackbar', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      state: readyState(),
      settings: onPrefs,
    );
    final completer = Completer<TranslationJobStatus?>();
    h.fake.retranslateCompleter = completer;

    await tester.tap(find.byTooltip('Retranslate'));
    await settleModal(tester);
    completer.complete(
      const TranslationJobStatus.failed(TranslationFailureKind.network),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'reopening modal while refreshing shows progress; lyrics body keeps old lines without placeholder',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        state: readyState(),
        settings: onPrefs,
      );
      final completer = Completer<TranslationJobStatus?>();
      h.fake.retranslateCompleter = completer;

      await tester.tap(find.byTooltip('Retranslate'));
      await settleModal(tester);
      expect(find.byType(LyricsTranslationModal), findsNothing);

      h.fake.emit(readyState(refreshing: true));
      await tester.pump();

      await tester.tap(find.text('Open modal'));
      await settleModal(tester);
      expect(find.text('Retranslating…'), findsOneWidget);
      expect(find.text('Retranslating; the old version stays'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.pumpWidget(
        translationApp(
          h.container,
          LyricsFoundBody(
            found: LyricsFound(defaultModalTrack.uri, defaultSyncedLyrics),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('The last kiss'), findsOneWidget);
      expect(find.byType(LyricsTranslationPlaceholder), findsNothing);
    },
  );
}
