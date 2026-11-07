import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

final _plugin = testTranslatePlugin;
final _en = translationLanguageFor('en')!;
final _key = TranslationJobKey('hash', 'en', _plugin);
final _otherKey = TranslationJobKey('hash2', 'en', _plugin);
final _lines = [for (var i = 0; i < 25; i++) 'line $i'];

const _aiConfig = [
  PluginConfigField(
    key: 'model',
    title: 'Model',
    mode: PluginConfigMode.select,
    selectFormat: PluginSelectFormat.single,
    defaultValue: 'flash',
    options: [
      PluginConfigOption(value: 'flash', title: 'Flash'),
      PluginConfigOption(value: 'pro', title: 'Pro'),
    ],
  ),
  PluginConfigField(
    key: 'style',
    title: 'Style',
    mode: PluginConfigMode.select,
    selectFormat: PluginSelectFormat.single,
    defaultValue: 'literal',
    options: [
      PluginConfigOption(value: 'literal', title: 'Literal'),
      PluginConfigOption(value: 'poetic', title: 'Poetic'),
    ],
  ),
  PluginConfigField(
    key: 'customInstruction',
    title: 'Instruction',
    mode: PluginConfigMode.input,
    inputFormat: PluginInputFormat.text,
  ),
];

/// Stands in for the plugins controller: ready at once, stored values from a
/// map the test changes.
class _FakeController implements LyricsPluginsController {
  Map<String, Object?> stored = {};

  @override
  Future<void> get ready async {}

  @override
  Future<Map<String, Object?>> storedConfig(String installId) async =>
      Map.of(stored);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late LibraryDatabase db;
  late FakePluginRunner runner;
  late ProviderContainer container;

  TranslationJobs jobs() => container.read(translationJobsProvider.notifier);
  Map<TranslationJobKey, TranslationJobStatus> status() =>
      container.read(translationJobsProvider);
  Future<List<LyricTranslationRow>> rows([String hash = 'hash']) =>
      db.watchLyricTranslations(hash, 'en').first;
  Future<BackgroundRunResult> background([TranslationJobKey? key]) =>
      jobs().runBackground(key ?? _key, _lines, _en);

  // The prefetch window holds [_key] and the screen is on [_otherKey].
  setUp(() async {
    db = memoryDb();
    runner = FakePluginRunner(
      spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
    );
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      settings: translationSettings(service: _plugin, acknowledged: {_plugin}),
      overrides: [
        pluginTranslateRunnerProvider.overrideWithValue(runner),
        translatePluginRecordsProvider.overrideWithValue(
          AsyncValue.data([translateRecord(_plugin.value)]),
        ),
      ],
    );
    container.listen(translationJobsProvider, (_, _) {});
    await songChoicesLoaded(container);
    jobs()
      ..setCurrent(_otherKey)
      ..setPrefetch({_key});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a saved background job leaves the saved status', () async {
    expect(await background(), BackgroundRunResult.saved);
    expect(runner.calls.map((c) => c.length), [10, 10, 5]);
    expect(await rows(), hasLength(1));
    expect(status()[_key]!.saved, isNotNull);
  });

  test('a failure is not in the state, the chunks done are kept and a normal '
      'run tries once more', () async {
    runner.errors[1] = failure(TranslationFailureKind.server);
    expect(await background(), BackgroundRunResult.failed);
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);

    jobs().setCurrent(_key);
    final end = await jobs().run(_key, _lines, _en);
    expect(end!.saved, isNotNull);
    // The first chunk is not sent again.
    expect(runner.calls.map((c) => c.length), [10, 10, 10, 5]);
    expect(runner.calls[2], _lines.sublist(10, 20));
  });

  test('a normal run that fails after a background failure shows it', () async {
    runner.errors[0] = failure(TranslationFailureKind.server);
    expect(await background(), BackgroundRunResult.failed);
    runner.errors[1] = failure(TranslationFailureKind.server);
    jobs().setCurrent(_key);
    await jobs().run(_key, _lines, _en);
    expect(status()[_key]!.failure, TranslationFailureKind.server);
  });

  test('the same job is not tried again in the background', () async {
    runner.errors[0] = failure(TranslationFailureKind.server);
    expect(await background(), BackgroundRunResult.failed);
    expect(await background(), BackgroundRunResult.skipped);
    expect(runner.calls, hasLength(1));
    // Another song of the same service is still tried.
    jobs().setPrefetch({_key, _otherKey});
    jobs().setCurrent(null);
    expect(await background(_otherKey), BackgroundRunResult.saved);
  });

  test('a service-level failure skips every song of that service until '
      'clearFailures', () async {
    runner.errors[0] = failure(TranslationFailureKind.rateLimited);
    jobs().setPrefetch({_key, _otherKey});
    jobs().setCurrent(null);
    expect(await background(), BackgroundRunResult.failed);
    final sent = runner.calls.length;

    expect(await background(_otherKey), BackgroundRunResult.skipped);
    expect(runner.calls, hasLength(sent));

    jobs().clearFailures(_plugin);
    expect(await background(_otherKey), BackgroundRunResult.saved);
    expect(await background(), BackgroundRunResult.saved);
  });

  test('a pending chunk is dropped while another current job runs, and the '
      'job is not counted as tried', () async {
    late Future<TranslationJobStatus?> current;
    runner.onSend = (i) {
      if (i == 0) current = jobs().run(_otherKey, _lines, _en);
    };
    expect(await background(), BackgroundRunResult.superseded);
    expect(status().containsKey(_key), isFalse);
    expect((await current)!.saved, isNotNull);

    runner.onSend = null;
    final before = runner.calls.length;
    expect(await background(), BackgroundRunResult.saved);
    // Only the two chunks the first attempt did not send.
    expect(runner.calls.length - before, 2);
    expect(await rows(), hasLength(1));
  });

  test('a song that becomes current mid-job is not dropped and does not '
      'resend', () async {
    runner.onSend = (i) {
      if (i == 0) {
        jobs()
          ..setCurrent(_key)
          ..setPrefetch({});
      }
    };
    expect(await background(), BackgroundRunResult.saved);
    expect(runner.calls.map((c) => c.length), [10, 10, 5]);
    expect(await rows(), hasLength(1));
  });

  test('a key that leaves the prefetch set drops the pending chunk but the '
      'lines of the chunk in flight are kept', () async {
    runner.hold = Completer<void>();
    final result = background();
    await until(() => runner.calls.length == 1);
    jobs().setPrefetch({});
    runner.hold!.complete();

    expect(await result, BackgroundRunResult.superseded);
    expect(runner.calls, hasLength(1));
    expect(status(), isEmpty);

    // The chunk that was in flight is not sent twice.
    jobs()
      ..setCurrent(_key)
      ..setPrefetch({});
    await jobs().run(_key, _lines, _en);
    expect(runner.calls.map((c) => c.length), [10, 10, 5]);
    expect(runner.calls[1], _lines.sublist(10, 20));
  });

  test(
    'the key shows as running meanwhile, so a normal run does nothing',
    () async {
      runner.hold = Completer<void>();
      final result = background();
      await until(() => runner.calls.length == 1);
      expect(status()[_key]!.isRunning, isTrue);
      expect(await jobs().run(_key, _lines, _en), isNull);
      expect(await background(), BackgroundRunResult.skipped);
      runner.hold!.complete();
      expect(await result, BackgroundRunResult.saved);
    },
  );

  test('a usable saved row is skipped', () async {
    expect(await background(), BackgroundRunResult.saved);
    runner.calls.clear();
    // Invalidating clears the saved status, so the saved row alone refuses it.
    container.invalidate(translationJobsProvider);
    container.listen(translationJobsProvider, (_, _) {});
    await songChoicesLoaded(container);
    jobs().setPrefetch({_key});
    expect(await background(), BackgroundRunResult.skipped);
    expect(runner.calls, isEmpty);
  });

  for (final (name, settings) in [
    ('translation is off', translationSettings(show: false)),
    ('the notice is not accepted', translationSettings(acknowledged: {})),
  ]) {
    test('nothing is sent when $name', () async {
      container.dispose();
      container = translationContainer(
        db: db,
        lyrics: FakeEmbeddedLyricsReader(),
        settings: settings,
        overrides: [
          pluginTranslateRunnerProvider.overrideWithValue(runner),
          translatePluginRecordsProvider.overrideWithValue(
            AsyncValue.data([translateRecord(_plugin.value)]),
          ),
        ],
      );
      container.listen(translationJobsProvider, (_, _) {});
      await songChoicesLoaded(container);
      jobs().setPrefetch({_key});
      expect(await background(), BackgroundRunResult.skipped);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
    });
  }

  test('a failure that lands after clearFailures does not break the service '
      'again', () async {
    runner.hold = Completer<void>();
    runner.errors[0] = failure(TranslationFailureKind.badKey);
    final result = background();
    await until(() => runner.calls.length == 1);
    jobs().clearFailures(_plugin);
    runner.hold!.complete();

    expect(await result, BackgroundRunResult.failed);
    runner.hold = null;
    jobs().setPrefetch({_key, _otherKey});
    jobs().setCurrent(null);
    expect(await background(_otherKey), BackgroundRunResult.saved);
    // The key itself is not remembered as tried either.
    expect(await background(), BackgroundRunResult.saved);
  });

  test('the tried memory is keyed by the AI settings snapshot', () async {
    container.dispose();
    final controller = _FakeController()..stored = {'model': 'pro'};
    final ai = FakePluginRunner(
      spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
      config: _aiConfig,
    );
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      settings: translationSettings(service: _plugin, acknowledged: {_plugin}),
      overrides: [
        pluginTranslateRunnerProvider.overrideWithValue(ai),
        translatePluginRecordsProvider.overrideWithValue(
          AsyncValue.data([
            translateRecord(_plugin.value, kind: PluginKind.aiTranslate),
          ]),
        ),
        lyricsPluginsControllerProvider.overrideWithValue(controller),
      ],
    );
    container.listen(translationJobsProvider, (_, _) {});
    await songChoicesLoaded(container);
    jobs()
      ..setCurrent(_otherKey)
      ..setPrefetch({_key});

    ai.errors[0] = failure(TranslationFailureKind.server);
    expect(await background(), BackgroundRunResult.failed);
    expect(ai.calls, hasLength(1));

    // Same settings: not sent again.
    expect(await background(), BackgroundRunResult.skipped);
    expect(ai.calls, hasLength(1));

    // Another model: tried again.
    controller.stored = {'model': 'flash'};
    expect(await background(), BackgroundRunResult.saved);
    expect(ai.calls, hasLength(greaterThan(1)));
  });

  test('currentKey and currentRunning follow the current job', () async {
    expect(jobs().currentKey, _otherKey);
    expect(jobs().currentRunning, isFalse);
    runner.hold = Completer<void>();
    final run = jobs().run(_otherKey, _lines, _en);
    expect(jobs().currentRunning, isTrue);
    runner.hold!.complete();
    await run;
    expect(jobs().currentRunning, isFalse);
  });
}
