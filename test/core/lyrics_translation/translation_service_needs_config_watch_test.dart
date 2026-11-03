import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_service_needs_config_watch.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_plugin_runner.dart';

const _id = 'plugin-abcdefghijkl';

class _Controller extends Fake implements LyricsPluginsController {
  _Controller(this.answer);

  final bool answer;

  @override
  Future<bool> needsConfig(String installId) async => answer;
}

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;

  ProviderContainer make({
    required bool needs,
    TranslationServiceId service = TranslationServiceId.google,
    bool live = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: TranslationPrefs(service: service)),
        ),
        lyricsPluginRecordsProvider.overrideWithValue([
          if (live) translateRecord(_id, name: 'Gemini'),
        ]),
        lyricsPluginsControllerProvider.overrideWithValue(_Controller(needs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(translationServiceNeedsConfigWatchProvider);
    return container;
  }

  void pick(ProviderContainer c, TranslationServiceId service) {
    final prefs = c.read(settingsProvider).translation;
    c
        .read(settingsProvider.notifier)
        .setTranslation(prefs.copyWith(service: service));
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a plugin already selected at startup reports nothing', () async {
    final c = make(needs: true, service: plugin);
    await settle();
    expect(c.read(pluginNeedsConfigNoticesProvider), isNull);
  });

  test('picking a plugin that needs config reports it', () async {
    final c = make(needs: true);
    pick(c, plugin);
    await settle();
    final notice = c.read(pluginNeedsConfigNoticesProvider);
    expect(notice?.installId, _id);
    expect(notice?.name, 'Gemini');
  });

  test('a plugin that needs nothing, Google and a gone plugin report none', () {
    final ok = make(needs: false);
    pick(ok, plugin);
    final back = make(needs: true, service: plugin);
    pick(back, TranslationServiceId.google);
    final gone = make(needs: true, live: false);
    pick(gone, plugin);
    return settle().then((_) {
      expect(ok.read(pluginNeedsConfigNoticesProvider), isNull);
      expect(back.read(pluginNeedsConfigNoticesProvider), isNull);
      expect(gone.read(pluginNeedsConfigNoticesProvider), isNull);
    });
  });

  test('an unrelated settings change reports nothing', () async {
    final c = make(needs: true, service: plugin);
    c.read(settingsProvider.notifier).setAnimations(false);
    await settle();
    expect(c.read(pluginNeedsConfigNoticesProvider), isNull);
  });
}
