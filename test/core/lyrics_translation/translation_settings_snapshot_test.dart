import 'dart:convert';

import 'package:crypto/crypto.dart';
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
import 'package:kanaru/core/lyrics_translation/lyrics_translation_derive.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune.dart';
import 'package:kanaru/core/lyrics_translation/translation_cache.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_job_work.dart';
import 'package:kanaru/core/lyrics_translation/queue_translation_choice.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart' as player;
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

const _config = [
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
  Object? error;

  @override
  Future<void> get ready async {}

  @override
  Future<Map<String, Object?>> storedConfig(String installId) async {
    if (error != null) throw error!;
    return Map.of(stored);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

String _hash(String text) => 'sha256:${sha256.convert(utf8.encode(text))}';

void main() {
  final plugin = testTranslatePlugin;
  final en = translationLanguageFor('en')!;
  final lines = ['one', 'two'];

  late LibraryDatabase db;
  late FakePluginRunner runner;
  late _FakeController controller;
  late ProviderContainer container;

  TranslationJobKey key(String hash) => TranslationJobKey(hash, 'en', plugin);

  Future<void> build({PluginKind kind = PluginKind.aiTranslate}) async {
    final record = translateRecord(plugin.value, kind: kind);
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      overrides: [
        pluginTranslateRunnerProvider.overrideWithValue(runner),
        translatePluginRecordsProvider.overrideWithValue(
          AsyncValue.data([record]),
        ),
        lyricsPluginsControllerProvider.overrideWithValue(controller),
      ],
    );
    container.listen(translationJobsProvider, (_, _) {});
    await songChoicesLoaded(container);
  }

  TranslationJobs jobs() => container.read(translationJobsProvider.notifier);

  Future<TranslationJobStatus?> run(String hash, {bool force = false}) {
    jobs().setCurrent(key(hash));
    return jobs().run(key(hash), lines, en, force: force);
  }

  Future<String?> settingsOf(String hash) async {
    final rows = await db.watchLyricTranslations(hash, 'en').first;
    expect(rows, hasLength(1));
    return rows.single.settingsJson;
  }

  setUp(() {
    db = memoryDb();
    controller = _FakeController();
    runner = FakePluginRunner(
      spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
      config: _config,
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('saves the settings the job starts with and sends the note', () async {
    controller.stored = {'model': 'pro', 'customInstruction': 'A'};
    await db.setSongTranslationInstruction('h1', 'B');
    await build();
    await run('h1');

    expect(decodeAiSnapshot(await settingsOf('h1')), {
      'model': 'pro',
      'style': 'literal',
      'instructionHash': _hash('A\nB'),
    });
    expect(runner.appends, [
      {'customInstruction': 'B'},
    ]);
  });

  test('a song without a note sends nothing extra', () async {
    controller.stored = {'model': 'pro', 'customInstruction': 'A'};
    await db.setSongTranslationInstruction('h1', 'B');
    await build();
    await run('h1');
    runner.appends.clear();
    await run('h2');

    expect(decodeAiSnapshot(await settingsOf('h2')), {
      'model': 'pro',
      'style': 'literal',
      'instructionHash': _hash('A'),
    });
    expect(runner.appends, [<String, String>{}]);
  });

  test("editing one song's note changes only that song's snapshot", () async {
    controller.stored = {'customInstruction': 'A'};
    await db.setSongTranslationInstruction('h1', 'B');
    await build();
    await run('h1');
    await run('h2');
    final before2 = await settingsOf('h2');

    await db.setSongTranslationInstruction('h1', 'B2');
    final tune = aiTuneOf(PluginKind.aiTranslate, _config)!;
    final stored = controller.stored;
    expect(
      aiTuneChanges(
        tune,
        decodeAiSnapshot(await settingsOf('h1')),
        stored,
        await db.songTranslationInstruction('h1'),
      ),
      hasLength(1),
    );
    expect(
      aiTuneChanges(tune, decodeAiSnapshot(before2), stored, null),
      isEmpty,
    );
  });

  test('a translate plugin saves no snapshot and sends no note', () async {
    controller.stored = {'model': 'pro'};
    await db.setSongTranslationInstruction('h1', 'B');
    await build(kind: PluginKind.translate);
    await run('h1');

    expect(await settingsOf('h1'), isNull);
    expect(runner.appends, [<String, String>{}]);
  });

  test('a retranslation replaces the snapshot, also with null', () async {
    controller.stored = {'model': 'pro'};
    await build();
    await run('h1');
    expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'pro');

    controller.stored = {'model': 'flash'};
    await run('h1', force: true);
    expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'flash');

    controller.error = StateError('boom');
    await run('h1', force: true);
    expect(await settingsOf('h1'), isNull);
  });

  test(
    'a failed read of the settings loses the snapshot, keeps the note',
    () async {
      controller.error = StateError('boom');
      await db.setSongTranslationInstruction('h1', 'B');
      await build();
      final status = await run('h1');

      expect(status!.saved, isNotNull);
      expect(await settingsOf('h1'), isNull);
      expect(runner.appends, [
        {'customInstruction': 'B'},
      ]);
    },
  );

  test('a retry after the note changed sends every chunk again', () async {
    controller.stored = {'customInstruction': 'A'};
    await db.setSongTranslationInstruction('h1', 'B');
    runner.errors[1] = failure(TranslationFailureKind.server);
    await build();
    final many = [for (var i = 0; i < 25; i++) 'line $i'];
    jobs().setCurrent(key('h1'));
    final failed = await jobs().run(key('h1'), many, en);
    expect(failed!.failure, TranslationFailureKind.server);
    expect(runner.calls, hasLength(2));

    runner.errors.clear();
    await db.setSongTranslationInstruction('h1', 'B2');
    jobs().clearFailure(key('h1'));
    final status = await jobs().run(key('h1'), many, en);

    expect(status!.saved, isNotNull);
    // Three chunks again, the first one included.
    expect(runner.calls, hasLength(5));
    expect(runner.calls[2], runner.calls[0]);
    expect(runner.appends.last, {'customInstruction': 'B2'});
    expect(decodeAiSnapshot(await settingsOf('h1')), {
      'model': 'flash',
      'style': 'literal',
      'instructionHash': _hash('A\nB2'),
    });
  });

  test('a retry under the same settings keeps the finished chunks', () async {
    controller.stored = {'customInstruction': 'A'};
    runner.errors[1] = failure(TranslationFailureKind.server);
    await build();
    final many = [for (var i = 0; i < 25; i++) 'line $i'];
    jobs().setCurrent(key('h1'));
    await jobs().run(key('h1'), many, en);
    runner.errors.clear();
    jobs().clearFailure(key('h1'));
    await jobs().run(key('h1'), many, en);

    // Chunk 0 once, then chunks 1 and 2 on the retry.
    expect(runner.calls, hasLength(4));
  });

  test('a change made between two chunks leaves the older snapshot', () async {
    controller.stored = {'model': 'pro'};
    runner.onSend = (index) {
      if (index == 0) controller.stored = {'model': 'flash'};
    };
    await build();
    final many = [for (var i = 0; i < 25; i++) 'line $i'];
    jobs().setCurrent(key('h1'));
    await jobs().run(key('h1'), many, en);

    expect(runner.calls.length, greaterThan(1));
    expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'pro');
  });

  test('the snapshot holds no free text', () async {
    controller.stored = {'customInstruction': 'secret words'};
    await db.setSongTranslationInstruction('h1', 'private note');
    await build();
    await run('h1');

    final json = (await settingsOf('h1'))!;
    expect(json, isNot(contains('secret')));
    expect(json, isNot(contains('private')));
    expect(json, contains('sha256:'));
  });

  test('the saved status differs when only the settings differ', () async {
    controller.stored = {'model': 'pro'};
    await build();
    final first = await run('h1');
    controller.stored = {'model': 'flash'};
    final second = await run('h1', force: true);

    expect(first!.saved, isNot(second!.saved));
  });

  group('derive', () {
    final info = TranslationTargetInfo(
      hash: 'h1',
      effective: en,
      songOverride: null,
      defaultTarget: en,
    );
    final lyrics = Lyrics(
      lines: [LyricLine(Duration.zero, 'one')],
      synced: false,
      source: LyricsSource.embedded,
    );
    CachedTranslation row(String? settings) => CachedTranslation(
      service: plugin,
      targetLang: 'en',
      sourceLang: 'ja',
      lines: const {'one': 'uno'},
      settingsJson: settings,
    );

    LyricsTranslationState derive(
      CachedTranslation r,
      TranslationJobStatus? job,
    ) => deriveTranslation(
      info: info,
      service: plugin,
      lyrics: lyrics,
      rows: [r],
      job: job,
    ).state;

    test('carries the snapshot into the ready state', () {
      final state = derive(row('{"model":"pro"}'), null) as TranslationReady;
      expect(state.settingsJson, '{"model":"pro"}');
    });

    test('keeps the old version until the row with new settings shows', () {
      final saved = TranslationJobStatus.saved(
        translationFingerprint(const {'one': 'uno'}, '{"model":"flash"}'),
      );
      final stale = derive(row('{"model":"pro"}'), saved) as TranslationReady;
      expect(stale.refreshing, isTrue);
      expect(stale.settingsJson, '{"model":"pro"}');

      final fresh = derive(row('{"model":"flash"}'), saved) as TranslationReady;
      expect(fresh.refreshing, isFalse);
      expect(fresh.settingsJson, '{"model":"flash"}');
    });
  });

  group('the tune of the winning tier', () {
    Future<void> setMode(
      TranslationScopePrecedence mode, {
      int? allChosenAt,
    }) async {
      final settings = container.read(settingsProvider.notifier);
      settings.setTranslation(
        container
            .read(settingsProvider)
            .translation
            .copyWith(scopePrecedence: mode, allChosenAt: allChosenAt),
      );
    }

    Future<void> songTune(Map<String, String> tune, {int at = 5}) =>
        db.setSongTranslationTune(
          'h1',
          service: plugin.value,
          tune: tune,
          chosenAt: at,
        );

    test(
      'reaches the script and the snapshot over the shared settings',
      () async {
        controller.stored = {'model': 'flash'};
        await songTune({'model': 'pro', 'style': 'poetic'});
        await build();
        await run('h1');

        expect(runner.overrides, [
          {'model': 'pro', 'style': 'poetic'},
        ]);
        final snap = decodeAiSnapshot(await settingsOf('h1'))!;
        expect(snap['model'], 'pro');
        expect(snap['style'], 'poetic');
      },
    );

    test('a song without a tune sends no override', () async {
      controller.stored = {'model': 'pro'};
      await build();
      await run('h1');

      expect(runner.overrides, [<String, Object?>{}]);
      expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'pro');
    });

    test(
      'an option the plugin dropped falls back to the shared value',
      () async {
        controller.stored = {'model': 'flash'};
        await songTune({'model': 'gone', 'style': 'poetic'});
        await build();
        await run('h1');

        expect(runner.overrides, [
          {'style': 'poetic'},
        ]);
        expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'flash');
      },
    );

    test('a model the user added themselves is kept', () async {
      runner = FakePluginRunner(
        spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
        config: [
          for (final f in _config)
            f.key == 'model'
                ? PluginConfigField(
                    key: f.key,
                    title: f.title,
                    mode: f.mode,
                    selectFormat: f.selectFormat,
                    defaultValue: f.defaultValue,
                    options: f.options,
                    custom: true,
                  )
                : f,
        ],
      );
      controller.stored = {
        'model': 'flash',
        'model.custom': [
          {'value': 'mine'},
        ],
      };
      await songTune({'model': 'mine'});
      await build();
      await run('h1');

      expect(runner.overrides.single, {'model': 'mine'});
    });

    Future<void> queueTune(Map<String, String> tune, int at) async {
      container.listen(playerServiceProvider, (_, _) {});
      container.listen(queueTranslationChoiceProvider, (_, _) {});
      await container.read(playerServiceProvider.notifier).openTracks([
        player.Track.fromPath('/music/a.mp3'),
      ]);
      container
          .read(queueTranslationChoiceProvider.notifier)
          .set(plugin, tune: tune, chosenAt: at);
    }

    test(
      'the queue tune reaches the script, the song tune is not mixed in',
      () async {
        controller.stored = {'model': 'flash'};
        await songTune({'model': 'pro', 'style': 'poetic'}, at: 5);
        await build();
        await queueTune({'model': 'pro'}, 20);
        await run('h1');

        expect(runner.overrides, [
          {'model': 'pro'},
        ]);
        final snap = decodeAiSnapshot(await settingsOf('h1'))!;
        expect(snap['style'], 'literal');
      },
    );

    test('a queue tune alone reaches the script', () async {
      controller.stored = {'model': 'flash'};
      await build();
      await queueTune({'model': 'pro', 'style': 'poetic'}, 20);
      await run('h1');

      expect(runner.overrides.single, {'model': 'pro', 'style': 'poetic'});
    });

    test('an unreadable config sends no override', () async {
      controller.error = StateError('boom');
      await songTune({'model': 'pro'});
      await build();
      await run('h1');

      expect(runner.overrides, [<String, Object?>{}]);
    });

    test(
      'an older song tune still wins when custom choices are kept',
      () async {
        controller.stored = {'model': 'flash'};
        await songTune({'model': 'pro'}, at: 5);
        await build();
        await setMode(TranslationScopePrecedence.keepCustom, allChosenAt: 10);
        await run('h1');

        expect(runner.overrides.single, {'model': 'pro'});
      },
    );

    test('an older song tune loses to a newer All songs choice', () async {
      controller.stored = {'model': 'flash'};
      await songTune({'model': 'pro'}, at: 5);
      await build();
      await setMode(TranslationScopePrecedence.replaceAll, allChosenAt: 10);
      await run('h1');

      expect(runner.overrides.single, isEmpty);
      expect(decodeAiSnapshot(await settingsOf('h1'))!['model'], 'flash');
    });
  });
}
