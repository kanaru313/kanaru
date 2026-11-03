import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_service_needs_config_watch.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import 'fake_translation_controller.dart';

const _google = TranslationServiceId.google;
const _id = 'plugin-abc123def456';

class _NeedsConfig extends Fake implements LyricsPluginsController {
  _NeedsConfig(this.answer);

  final bool answer;

  @override
  Future<bool> needsConfig(String installId) async => answer;
}

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;
  late ProviderContainer container;

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  Future<void> pump(
    WidgetTester tester, {
    required TranslationPrefs settings,
    String pluginName = 'Gemini',
    AsyncValue<List<LyricsPluginRecord>>? recordsState,
    bool openService = true,
    bool needsConfig = false,
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final live = [translateRecord(_id, name: pluginName)];
    container = ProviderContainer(
      overrides: [
        fakeTranslationOverride(
          FakeTranslationController(TranslationOff(fakeTranslationInfo())),
        ),
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: settings),
        ),
        lyricsPluginRecordsProvider.overrideWithValue([...live]),
        lyricsPluginsControllerProvider.overrideWithValue(
          _NeedsConfig(needsConfig),
        ),
        translatePluginRecordsProvider.overrideWithValue(
          recordsState ?? AsyncValue.data([...live]),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The shell keeps this watcher alive in the app.
    container.read(translationServiceNeedsConfigWatchProvider);
    await tester.pumpWidget(
      translationApp(container, const LyricsTranslationButton()),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (openService) {
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
    }
  }

  Finder radio(String name) =>
      find.widgetWithText(RadioMenuButton<TranslationServiceId>, name);

  testWidgets('the service submenu lists Google and plugins by name', (
    tester,
  ) async {
    await pump(
      tester,
      settings: const TranslationPrefs(noticeAcknowledged: {_google}),
    );

    expect(radio('Google'), findsOneWidget);
    expect(radio('Gemini'), findsOneWidget);
  });

  testWidgets('a plugin that was not accepted asks while translation is on', (
    tester,
  ) async {
    await pump(
      tester,
      settings: const TranslationPrefs(
        show: true,
        noticeAcknowledged: {_google},
      ),
    );

    await tester.tap(radio('Gemini'));
    await tester.pumpAndSettle();

    expect(
      find.text('Lyrics will be sent to the plugin Gemini'),
      findsOneWidget,
    );
    expect(prefs().service, _google);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(prefs().service, plugin);
    expect(prefs().noticeAcknowledged, {_google, plugin});
  });

  testWidgets('an accepted plugin is picked at once', (tester) async {
    await pump(
      tester,
      settings: TranslationPrefs(
        show: true,
        noticeAcknowledged: {_google, plugin},
      ),
    );

    await tester.tap(radio('Gemini'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs().service, plugin);
  });

  testWidgets('a stored plugin that is gone shows Google as picked', (
    tester,
  ) async {
    await pump(
      tester,
      settings: TranslationPrefs(
        service: TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!,
      ),
    );

    final google = tester.widget<RadioMenuButton<TranslationServiceId>>(
      radio('Google'),
    );
    expect(google.groupValue, _google);
    expect(prefs().service.value, 'plugin-zzzzzzzzzzzz');
  });

  testWidgets('Cancel on the notice changes nothing', (tester) async {
    await pump(
      tester,
      settings: const TranslationPrefs(
        show: true,
        noticeAcknowledged: {_google},
      ),
    );

    await tester.tap(radio('Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(prefs().service, _google);
    expect(prefs().noticeAcknowledged, {_google});
  });

  testWidgets('picking a plugin that needs config reports it', (tester) async {
    await pump(
      tester,
      settings: TranslationPrefs(noticeAcknowledged: {_google, plugin}),
      needsConfig: true,
    );

    await tester.tap(radio('Gemini'));
    await tester.pumpAndSettle();

    expect(prefs().service, plugin);
    final notice = container.read(pluginNeedsConfigNoticesProvider);
    expect(notice?.installId, _id);
    expect(notice?.name, 'Gemini');
  });

  testWidgets('Cancel on the notice reports nothing', (tester) async {
    await pump(
      tester,
      settings: const TranslationPrefs(
        show: true,
        noticeAcknowledged: {_google},
      ),
      needsConfig: true,
    );

    await tester.tap(radio('Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(pluginNeedsConfigNoticesProvider), isNull);
  });

  testWidgets('a plugin named Google shows as Google (plugin)', (tester) async {
    await pump(
      tester,
      settings: const TranslationPrefs(noticeAcknowledged: {_google}),
      pluginName: 'Google',
    );

    expect(radio('Google (plugin)'), findsOneWidget);
    expect(radio('Google'), findsOneWidget);
  });

  for (final (label, state) in [
    ('loading', const AsyncValue<List<LyricsPluginRecord>>.loading()),
    (
      'unreadable',
      AsyncValue<List<LyricsPluginRecord>>.error('x', StackTrace.empty),
    ),
  ]) {
    testWidgets(
      'records $label: the stored plugin shows, nothing can be picked',
      (tester) async {
        await pump(
          tester,
          settings: TranslationPrefs(
            service: plugin,
            noticeAcknowledged: {plugin},
          ),
          recordsState: state,
        );

        final selected = tester.widget<RadioMenuButton<TranslationServiceId>>(
          find.byType(RadioMenuButton<TranslationServiceId>).first,
        );
        expect(selected.groupValue, plugin);
        for (final r
            in tester.widgetList<RadioMenuButton<TranslationServiceId>>(
              find.byType(RadioMenuButton<TranslationServiceId>),
            )) {
          expect(r.onChanged, isNull);
        }
        await tester.tap(radio('Google'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(prefs().service, plugin);
      },
    );
  }
}
