import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart'
    show PluginConfigField;
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';

import '../lyrics/fake_lyrics_readers.dart';
import '../lyrics/plugins/store/store_test_env.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

/// A runner whose `spec` reads the database record like the real one, so a
/// job that skips the controller's `ready` meets a record with no spec.
class _DbSpecRunner extends FakePluginRunner {
  _DbSpecRunner(this.store);

  final StoreEnv store;

  @override
  Future<PluginTranslateInfo> spec(String installId) async {
    final row = await store.db.lyricsPluginById(installId);
    final record = LyricsPluginRecord.fromRow(row!);
    final declared = record.translate;
    if (declared == null) {
      throw const TranslationException(TranslationFailureKind.invalidResponse);
    }
    return (spec: declared, hosts: record.hosts, config: <PluginConfigField>[]);
  }
}

void main() {
  late StoreEnv store;

  setUp(() async => store = await StoreEnv.create());
  tearDown(() => store.dispose());

  test('a job started at once waits for the startup backfill', () async {
    final installed = await store.controller.installPackage(
      testPackage(kind: PluginKind.translate),
      const PluginInstallSource.file('t.zip'),
    );
    await store.db.customStatement(
      'UPDATE lyrics_plugins SET translate_spec = NULL',
    );
    // A new session: its backfill is queued but has not run yet.
    final fresh = store.newController();
    final service = TranslationServiceId.tryParse(installed.installId)!;
    final key = TranslationJobKey('hash', 'en', service);
    final runner = _DbSpecRunner(store);
    final container = translationContainer(
      db: store.db,
      lyrics: FakeEmbeddedLyricsReader(),
      settings: translationSettings(service: service, acknowledged: {service}),
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(fresh),
        pluginTranslateRunnerProvider.overrideWithValue(runner),
        translatePluginRecordsProvider.overrideWithValue(
          AsyncValue.data([installed]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(translationJobsProvider, (_, _) {});
    final jobs = container.read(translationJobsProvider.notifier)
      ..setCurrent(key);

    await jobs.run(key, const ['a', 'b'], translationLanguageFor('en')!);

    final status = container.read(translationJobsProvider)[key]!;
    expect(status.failure, isNull);
    expect(runner.calls, isNotEmpty);
  });
}
