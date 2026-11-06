import 'dart:async';

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
  _Controller(this.answer, {this.gate});

  final bool answer;

  /// When set, the check waits for it.
  final Completer<void>? gate;

  @override
  Future<bool> needsConfig(String installId) async {
    await gate?.future;
    return answer;
  }
}

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;
  final other = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;

  ProviderContainer make({
    required bool needs,
    TranslationServiceId? service,
    bool live = true,
    Completer<void>? gate,
  }) {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: TranslationPrefs(service: service)),
        ),
        lyricsPluginRecordsProvider.overrideWithValue([
          if (live) translateRecord(_id, name: 'Gemini'),
        ]),
        lyricsPluginsControllerProvider.overrideWithValue(
          _Controller(needs, gate: gate),
        ),
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

  test('picking a plugin from null reports it', () async {
    final c = make(needs: true, service: null);
    pick(c, plugin);
    await settle();
    final notice = c.read(pluginNeedsConfigNoticesProvider);
    expect(notice?.installId, _id);
    expect(notice?.name, 'Gemini');
  });

  test('a plugin that needs nothing and a gone plugin report none', () {
    final ok = make(needs: false);
    pick(ok, plugin);
    final back = make(needs: true, service: plugin);
    pick(back, other);
    final gone = make(needs: true, live: false);
    pick(gone, plugin);
    return settle().then((_) {
      expect(ok.read(pluginNeedsConfigNoticesProvider), isNull);
      expect(back.read(pluginNeedsConfigNoticesProvider), isNull);
      expect(gone.read(pluginNeedsConfigNoticesProvider), isNull);
    });
  });

  test('the service changed again during the check reports nothing', () async {
    final gate = Completer<void>();
    final c = make(needs: true, gate: gate);
    pick(c, plugin);
    await settle();
    pick(c, other);
    gate.complete();
    await settle();
    expect(c.read(pluginNeedsConfigNoticesProvider), isNull);
  });

  test('an unrelated settings change reports nothing', () async {
    final c = make(needs: true, service: plugin);
    c.read(settingsProvider.notifier).setAnimations(false);
    await settle();
    expect(c.read(pluginNeedsConfigNoticesProvider), isNull);
  });
}
