import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics_translation/translation_service_names.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/translation_service_name.dart';

import 'fake_plugin_runner.dart';

const _id = 'plugin-abc123def456';
const _removedId = 'plugin-zzzzzzzzzzzz';

void main() {
  final l10n = AppLocalizationsEn();

  Map<String, TranslationPluginInfo> infos(List<LyricsPluginRecord> records) {
    final container = ProviderContainer(
      overrides: [
        lyricsPluginRecordsProvider.overrideWithValue([...records]),
      ],
    );
    addTearDown(container.dispose);
    return container.read(translationPluginInfosProvider);
  }

  String name(Map<String, TranslationPluginInfo> m, String id) =>
      translationServiceName(l10n, m, TranslationServiceId.tryParse(id)!);

  test('a plugin shows its record name', () {
    final m = infos([translateRecord(_id)]);

    expect(name(m, _id), 'Plugin $_id');
    expect(m[_id]!.hosts, ['api.example.com']);
  });

  test('a removed record keeps its name, marked removed', () {
    final m = infos([translateRecord(_removedId, removed: true)]);

    expect(name(m, _removedId), 'Plugin $_removedId (removed)');
  });

  test('lyrics plugins are not translation services', () {
    final m = infos([translateRecord(_id, kind: PluginKind.lyrics)]);

    expect(m, isEmpty);
    expect(name(m, _id), _id);
  });
}
