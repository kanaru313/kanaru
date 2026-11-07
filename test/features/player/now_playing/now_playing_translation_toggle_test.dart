import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_translation_toggle.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../lyrics/translation/modal/translation_modal_harness.dart';

void main() {
  late ProviderContainer container;
  var opened = 0;

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  Future<void> pumpToggle(
    WidgetTester tester, {
    required TranslationPrefs settings,
    List<Override>? pluginOverrides,
    bool hasLyrics = true,
    TranslationServiceId? songService,
  }) async {
    opened = 0;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: settings),
        ),
        ...(pluginOverrides ?? translatePluginOverrides()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => quickToggleLyricsTranslation(
                  context,
                  ref,
                  hasLyrics: hasLyrics,
                  openModal: () => opened++,
                  songService: songService,
                ),
                child: const Text('Toggle'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  TranslationPrefs acknowledged({bool show = false}) => TranslationPrefs(
    show: show,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin},
  );

  testWidgets('turning off works and never opens the notice or the modal', (
    tester,
  ) async {
    await pumpToggle(tester, settings: acknowledged(show: true));
    await toggle(tester);
    expect(prefs().show, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(opened, 0);
  });

  testWidgets('first enable asks the notice; Continue turns it on', (
    tester,
  ) async {
    await pumpToggle(
      tester,
      settings: TranslationPrefs(service: testTranslatePlugin),
    );
    await toggle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(prefs().show, isFalse);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(prefs().show, isTrue);
    expect(prefs().noticeAcknowledged, {testTranslatePlugin});
    expect(opened, 0);
  });

  testWidgets('acknowledged service turns on without a notice', (tester) async {
    await pumpToggle(tester, settings: acknowledged());
    await toggle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs().show, isTrue);
  });

  testWidgets('no service selected calls openModal and changes nothing', (
    tester,
  ) async {
    await pumpToggle(tester, settings: const TranslationPrefs());
    await toggle(tester);
    expect(opened, 1);
    expect(prefs().show, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('plugin records still loading: nothing happens', (tester) async {
    await pumpToggle(
      tester,
      settings: const TranslationPrefs(),
      pluginOverrides: [
        translatePluginRecordsProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    await toggle(tester);
    expect(opened, 0);
    expect(prefs().show, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('no lyrics: turning on does nothing', (tester) async {
    await pumpToggle(tester, settings: acknowledged(), hasLyrics: false);
    await toggle(tester);
    expect(opened, 0);
    expect(prefs().show, isFalse);
  });

  group("a song with its own service", () {
    final own = TranslationServiceId.tryParse('plugin-111111111111')!;

    testWidgets('turns on with the default and keeps it the default', (
      tester,
    ) async {
      await pumpToggle(
        tester,
        settings: acknowledged(),
        songService: testTranslatePlugin,
      );
      await toggle(tester);
      expect(prefs().show, isTrue);
      expect(prefs().service, testTranslatePlugin);
      expect(prefs().allChosenAt, isNull);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('asks about the song\'s service when it was not accepted', (
      tester,
    ) async {
      await pumpToggle(tester, settings: acknowledged(), songService: own);
      await toggle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(prefs().show, isFalse);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(prefs().show, isTrue);
      expect(prefs().noticeAcknowledged, {testTranslatePlugin, own});
      // The default and its stamp are untouched.
      expect(prefs().service, testTranslatePlugin);
      expect(prefs().allChosenAt, isNull);
    });

    testWidgets('cancelling the song\'s service still turns on the default', (
      tester,
    ) async {
      await pumpToggle(
        tester,
        settings: TranslationPrefs(
          service: testTranslatePlugin,
          noticeAcknowledged: {testTranslatePlugin},
          allChosenAt: 5,
        ),
        songService: own,
      );
      await toggle(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(prefs().show, isTrue);
      expect(prefs().service, testTranslatePlugin);
      expect(prefs().noticeAcknowledged, {testTranslatePlugin});
      expect(prefs().allChosenAt, 5);
    });

    testWidgets('first enable asks the default, then the song\'s service', (
      tester,
    ) async {
      await pumpToggle(
        tester,
        settings: TranslationPrefs(service: testTranslatePlugin),
        songService: own,
      );
      await toggle(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(prefs().show, isFalse);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(prefs().show, isTrue);
      expect(prefs().noticeAcknowledged, {testTranslatePlugin, own});
      expect(prefs().allChosenAt, isNull);
    });

    testWidgets('on, with the song\'s service not accepted: asks, never off', (
      tester,
    ) async {
      await pumpToggle(
        tester,
        settings: acknowledged(show: true),
        songService: own,
      );
      await toggle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(prefs().show, isTrue);
    });
  });
}
