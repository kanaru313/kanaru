import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

final _plugin = testTranslatePlugin;
final _en = translationLanguageFor('en')!;
final _key = TranslationJobKey('hash', 'en', _plugin);
final _otherKey = TranslationJobKey('hash2', 'en', _plugin);
final _lines = [for (var i = 0; i < 25; i++) 'line $i'];

/// The translate plugin list the tests change while the container lives.
class _Records extends Notifier<AsyncValue<List<LyricsPluginRecord>>> {
  @override
  AsyncValue<List<LyricsPluginRecord>> build() =>
      AsyncValue.data([translateRecord(_plugin.value)]);

  void set(AsyncValue<List<LyricsPluginRecord>> value) => state = value;
}

final _records =
    NotifierProvider<_Records, AsyncValue<List<LyricsPluginRecord>>>(
      _Records.new,
    );

void main() {
  late LibraryDatabase db;
  late FakePluginRunner runner;
  late ProviderContainer container;

  TranslationJobs jobs() => container.read(translationJobsProvider.notifier);
  Map<TranslationJobKey, TranslationJobStatus> status() =>
      container.read(translationJobsProvider);
  Future<List<LyricTranslationRow>> rows([String hash = 'hash']) =>
      db.watchLyricTranslations(hash, 'en').first;

  void build({
    Set<TranslationServiceId> acknowledged = const {
      TranslationServiceId.google,
    },
    bool withRunner = true,
    bool ackPlugin = true,
  }) {
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      settings: translationSettings(
        service: _plugin,
        acknowledged: {if (ackPlugin) _plugin, ...acknowledged},
      ),
      overrides: [
        pluginTranslateRunnerProvider.overrideWithValue(
          withRunner ? runner : null,
        ),
        translatePluginRecordsProvider.overrideWith(
          (ref) => ref.watch(_records),
        ),
      ],
    );
    container.listen(translationJobsProvider, (_, _) {});
    jobs().setCurrent(_key);
  }

  setUp(() {
    db = memoryDb();
    runner = FakePluginRunner(
      spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'chunks follow the plugin limits and the row is saved under its id',
    () async {
      build();
      await jobs().run(_key, _lines, _en);

      expect(runner.calls.map((c) => c.length), [10, 10, 5]);
      final saved = (await rows()).single;
      expect(saved.provider, _plugin.value);
      expect(saved.linesJson, contains('tr:line 24'));
      expect(status()[_key]!.saved, isNotNull);
    },
  );

  test(
    'a failed second chunk saves nothing and retry sends only the rest',
    () async {
      build();
      runner.errors[1] = failure(TranslationFailureKind.server);
      await jobs().run(_key, _lines, _en);

      expect(status()[_key]!.failure, TranslationFailureKind.server);
      expect(await rows(), isEmpty);

      jobs().clearFailure(_key);
      await jobs().run(_key, _lines, _en);
      expect(runner.calls.map((c) => c.length), [10, 10, 10, 5]);
      expect(runner.calls[2], _lines.sublist(10, 20));
      expect(await rows(), hasLength(1));
    },
  );

  test('clearFailures drops the chunks of that service too', () async {
    build();
    runner.errors[1] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en);

    jobs().clearFailures(_plugin);
    await jobs().run(_key, _lines, _en);

    expect(runner.calls[2], _lines.sublist(0, 10));
  });

  test('an updated plugin discards the chunks done before', () async {
    build();
    runner.errors[1] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en);

    container
        .read(_records.notifier)
        .set(AsyncValue.data([translateRecord(_plugin.value, updatedAt: 9)]));
    jobs().clearFailure(_key);
    await jobs().run(_key, _lines, _en);

    expect(runner.calls[2], _lines.sublist(0, 10));
  });

  test('a chunk of a job no longer wanted is dropped, quietly', () async {
    build();
    runner.onSend = (i) {
      if (i == 0) jobs().setCurrent(_otherKey);
    };
    await jobs().run(_key, _lines, _en);

    expect(runner.calls, hasLength(1));
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);

    // Back on this song: the chunk done is not sent twice.
    runner.onSend = null;
    jobs().setCurrent(_key);
    await jobs().run(_key, _lines, _en);
    expect(runner.calls.map((c) => c.length), [10, 10, 5]);
    expect(runner.calls[1], _lines.sublist(10, 20));
    expect(await rows(), hasLength(1));
  });

  test('a forced run is wanted whatever is current', () async {
    build();
    jobs().setCurrent(_otherKey);
    await jobs().run(_key, _lines, _en, force: true);

    expect(runner.calls, hasLength(3));
    expect(await rows(), hasLength(1));
  });

  test('turning translation off between chunks sends nothing more', () async {
    build();
    runner.onSend = (i) {
      if (i == 0) {
        container.read(settingsProvider.notifier).toggleLyricsTranslation();
      }
    };
    await jobs().run(_key, _lines, _en);

    expect(runner.calls, hasLength(1));
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);

    // Turned on again: the chunk done is kept, only the rest is sent.
    runner.onSend = null;
    container.read(settingsProvider.notifier).toggleLyricsTranslation();
    await jobs().run(_key, _lines, _en);
    expect(runner.calls.map((c) => c.length), [10, 10, 5]);
    expect(runner.calls[1], _lines.sublist(10, 20));
    expect(await rows(), hasLength(1));
  });

  test('clearFailures while a job runs: it saves nothing', () async {
    build();
    runner.onSend = (i) {
      if (i == 0) jobs().clearFailures(_plugin);
    };
    await jobs().run(_key, _lines, _en);

    expect(runner.calls, hasLength(3));
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);
  });

  test('a plugin without an accepted notice is never called', () async {
    build(ackPlugin: false);
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en, force: true);
    expect(runner.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test(
    'a plugin that is not the chosen service, or is gone, is never called',
    () async {
      build();
      container
          .read(settingsProvider.notifier)
          .setTranslation(
            container
                .read(settingsProvider)
                .translation
                .copyWith(service: TranslationServiceId.google),
          );
      await jobs().run(_key, _lines, _en);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
      container.dispose();

      build();
      container.read(_records.notifier).set(const AsyncValue.data([]));
      await jobs().run(_key, _lines, _en);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
    },
  );

  test('while the plugin list loads nothing is sent', () async {
    build();
    container.read(_records.notifier).set(const AsyncValue.loading());
    await jobs().run(_key, _lines, _en);
    expect(runner.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test('no runner: the job fails as a server error', () async {
    build(withRunner: false);
    await jobs().run(_key, _lines, _en);
    expect(status()[_key]!.failure, TranslationFailureKind.server);
  });

  test(
    'more chunks than a plugin job may need: tooLong, nothing sent',
    () async {
      build();
      await jobs().run(_key, [for (var i = 0; i < 230; i++) 'l$i'], _en);
      expect(status()[_key]!.failure, TranslationFailureKind.tooLong);
      expect(runner.calls, isEmpty);
    },
  );
}
