import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import '../player/fake_audio_backend.dart';
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

  Future<void> build({
    Set<TranslationServiceId> acknowledged = const {},
    bool withRunner = true,
    bool ackPlugin = true,
  }) async {
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
    await songChoicesLoaded(container);
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
      await build();
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
      await build();
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
    await build();
    runner.errors[1] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en);

    jobs().clearFailures(_plugin);
    await jobs().run(_key, _lines, _en);

    expect(runner.calls[2], _lines.sublist(0, 10));
  });

  test('an updated plugin discards the chunks done before', () async {
    await build();
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
    await build();
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
    await build();
    jobs().setCurrent(_otherKey);
    await jobs().run(_key, _lines, _en, force: true);

    expect(runner.calls, hasLength(3));
    expect(await rows(), hasLength(1));
  });

  test('turning translation off between chunks sends nothing more', () async {
    await build();
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

  group('the service chosen for the song', () {
    final other = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;

    // Two live translate plugins, and a song choice written to the database
    // that the jobs have seen.
    Future<void> chooseForSong(TranslationServiceId service, int at) async {
      container
          .read(_records.notifier)
          .set(
            AsyncValue.data([
              translateRecord(_plugin.value),
              translateRecord(other.value),
            ]),
          );
      container
          .read(settingsProvider.notifier)
          .acknowledgeTranslationNotice(other);
      await db.setSongTranslationService(
        _key.hash,
        service.value,
        chosenAt: at,
      );
      await until(
        () =>
            container
                .read(songTranslationOverridesProvider)
                .value
                ?.containsKey(_key.hash) ==
            true,
      );
    }

    test(
      'a key of the default is refused when the song chose another',
      () async {
        await build();
        await chooseForSong(other, 10);
        await jobs().run(_key, _lines, _en);

        expect(runner.calls, isEmpty);
        expect(status(), isEmpty);

        // The song's own service is the one that may run.
        final ownKey = TranslationJobKey(_key.hash, 'en', other);
        jobs().setCurrent(ownKey);
        await jobs().run(ownKey, _lines, _en);
        expect(runner.calls, isNotEmpty);
      },
    );

    test('a stamp-only change between chunks stops the job', () async {
      await build();
      await chooseForSong(other, 10);
      final ownKey = TranslationJobKey(_key.hash, 'en', other);
      jobs().setCurrent(ownKey);
      runner.onSend = (i) {
        // Same default service; only the stamp moves past the song's.
        if (i == 0) {
          container
              .read(settingsProvider.notifier)
              .enableTranslation(_plugin, allChosenAt: 20);
        }
      };
      await jobs().run(ownKey, _lines, _en);

      expect(runner.calls, hasLength(1));
      expect(status(), isEmpty);
      expect(await rows(), isEmpty);
    });

    test('while the song choices are unknown nothing is sent', () async {
      await build();
      // A fresh container whose song-choice stream never emits.
      container.dispose();
      container = translationContainer(
        db: db,
        lyrics: FakeEmbeddedLyricsReader(),
        settings: translationSettings(
          service: _plugin,
          acknowledged: {_plugin},
        ),
        overrides: [
          pluginTranslateRunnerProvider.overrideWithValue(runner),
          translatePluginRecordsProvider.overrideWithValue(
            AsyncValue.data([translateRecord(_plugin.value)]),
          ),
          songTranslationOverridesProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      container.listen(translationJobsProvider, (_, _) {});
      jobs().setCurrent(_key);

      expect(await jobs().run(_key, _lines, _en), isNull);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
    });

    test('jobs alone keep the song choices running', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          libraryDatabaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(
            translationSettings(service: _plugin, acknowledged: {_plugin}),
          ),
          pluginTranslateRunnerProvider.overrideWithValue(runner),
          translatePluginRecordsProvider.overrideWithValue(
            AsyncValue.data([translateRecord(_plugin.value)]),
          ),
        ],
      );
      // Only jobs are listened to; the map is not.
      container.listen(translationJobsProvider, (_, _) {});
      jobs().setCurrent(_key);
      await container.read(songTranslationOverridesProvider.future);

      await jobs().run(_key, _lines, _en);

      expect(runner.calls, isNotEmpty);
    });

    test('an "All songs" choice made between chunks stops the job', () async {
      await build();
      await chooseForSong(_plugin, 10);
      runner.onSend = (i) {
        if (i == 0) {
          // Newer than the song's choice, and another service.
          container
              .read(settingsProvider.notifier)
              .enableTranslation(other, allChosenAt: 20);
        }
      };
      await jobs().run(_key, _lines, _en);

      expect(runner.calls, hasLength(1));
      expect(status(), isEmpty);
      expect(await rows(), isEmpty);
    });
  });

  test('clearFailures while a job runs: it saves nothing', () async {
    await build();
    runner.onSend = (i) {
      if (i == 0) jobs().clearFailures(_plugin);
    };
    await jobs().run(_key, _lines, _en);

    expect(runner.calls, hasLength(3));
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);
  });

  test('a plugin without an accepted notice is never called', () async {
    await build(ackPlugin: false);
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en, force: true);
    expect(runner.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test(
    'a plugin that is not the chosen service, or is gone, is never called',
    () async {
      final other = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;
      await build();
      container
          .read(settingsProvider.notifier)
          .setTranslation(
            container
                .read(settingsProvider)
                .translation
                .copyWith(service: other),
          );
      await jobs().run(_key, _lines, _en);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
      container.dispose();

      await build();
      container.read(_records.notifier).set(const AsyncValue.data([]));
      await jobs().run(_key, _lines, _en);
      expect(runner.calls, isEmpty);
      expect(status(), isEmpty);
    },
  );

  test('while the plugin list loads nothing is sent', () async {
    await build();
    container.read(_records.notifier).set(const AsyncValue.loading());
    await jobs().run(_key, _lines, _en);
    expect(runner.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test('no runner: the job fails as a server error', () async {
    await build(withRunner: false);
    await jobs().run(_key, _lines, _en);
    expect(status()[_key]!.failure, TranslationFailureKind.server);
  });

  test(
    'more chunks than a plugin job may need: tooLong, nothing sent',
    () async {
      await build();
      await jobs().run(_key, [for (var i = 0; i < 230; i++) 'l$i'], _en);
      expect(status()[_key]!.failure, TranslationFailureKind.tooLong);
      expect(runner.calls, isEmpty);
    },
  );

  group('cancel', () {
    final two = _lines.sublist(0, 15); // two chunks of at most 10

    Future<void> sent(int chunks) async {
      for (var i = 0; i < 50 && runner.calls.length < chunks; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(runner.calls, hasLength(chunks));
    }

    test('before the next chunk: it is not sent, nothing saved', () async {
      await build();
      runner.onSend = (i) {
        if (i == 0) {
          jobs().cancel(_key);
          expect(status(), isEmpty); // gone at once
        }
      };
      final result = await jobs().run(_key, two, _en, force: true);

      expect(result, isNull);
      expect(runner.calls, hasLength(1));
      expect(status(), isEmpty);
      expect(await rows(), isEmpty);
    });

    test('a chunk in flight that fails after it: no failure, next run '
        'works', () async {
      await build();
      runner.hold = Completer<void>();
      runner.errors[0] = failure(TranslationFailureKind.server);
      final run = jobs().run(_key, two, _en, force: true);
      await sent(1);
      expect(status()[_key]!.isRunning, isTrue);

      jobs().cancel(_key);
      expect(status(), isEmpty);
      runner.hold!.complete();
      expect(await run, isNull);
      expect(status(), isEmpty);

      runner.hold = null;
      runner.errors.clear();
      final again = await jobs().run(_key, two, _en, force: true);
      expect(again?.saved, isNotNull);
      expect(runner.calls.length, greaterThan(2));
      expect(await rows(), hasLength(1));
    });

    test('cancel then retranslate while the old chunk flies: only the new '
        'run saves', () async {
      await build();
      final hold = Completer<void>();
      runner.hold = hold;
      final old = jobs().run(_key, two, _en, force: true);
      await sent(1);

      jobs().cancel(_key);
      runner.hold = null;
      runner.transform = (line) => 'new:$line';
      // The gate sends one chunk at a time: the new run waits for the old one.
      final freshRun = jobs().run(_key, two, _en, force: true);
      hold.complete();
      expect(await old, isNull);
      final fresh = await freshRun;
      expect(fresh?.saved, isNotNull);
      expect(status()[_key], fresh);
      final saved = await rows();
      expect(saved, hasLength(1));
      expect(saved.single.linesJson, contains('new:line 0'));
      expect(saved.single.linesJson, isNot(contains('tr:line 0')));
    });

    test('the last chunk back after cancel is not saved', () async {
      await build();
      runner.hold = Completer<void>();
      final run = jobs().run(_key, _lines.sublist(0, 5), _en, force: true);
      await sent(1);
      jobs().cancel(_key);
      runner.hold!.complete();

      expect(await run, isNull);
      expect(status(), isEmpty);
      expect(await rows(), isEmpty);
    });

    test('a cancelled retranslate drops its partial', () async {
      await build();
      runner.onSend = (i) {
        if (i == 0) jobs().cancel(_key);
      };
      expect(await jobs().run(_key, two, _en, force: true), isNull);
      expect(runner.calls, hasLength(1));

      // A normal run finds no chunk kept: it sends both chunks again.
      runner.onSend = null;
      final again = await jobs().run(_key, two, _en);
      expect(again?.saved, isNotNull);
      expect(runner.calls, hasLength(3));
    });

    test('a retranslate started after the cancel keeps its partial', () async {
      await build();
      final hold = Completer<void>();
      runner.hold = hold;
      final old = jobs().run(_key, two, _en, force: true);
      await sent(1);
      jobs().cancel(_key);

      // The new run waits for the old chunk, sends chunk 1, then fails on 2.
      runner.hold = null;
      runner.errors[2] = failure(TranslationFailureKind.server);
      final fresh = jobs().run(_key, two, _en, force: true);
      hold.complete();
      expect(await old, isNull);
      expect((await fresh)?.failure, TranslationFailureKind.server);

      // The old run's cleanup left the new run's chunk: Retry sends only the
      // chunk that failed.
      runner.errors.clear();
      jobs().clearFailure(_key);
      final before = runner.calls.length;
      final retry = await jobs().run(_key, two, _en);
      expect(retry?.saved, isNotNull);
      expect(runner.calls.length - before, 1);
    });

    test('a job that is not forced ignores it', () async {
      await build();
      runner.hold = Completer<void>();
      final run = jobs().run(_key, _lines.sublist(0, 5), _en);
      await sent(1);
      jobs().cancel(_key);
      expect(status()[_key]!.isRunning, isTrue);
      runner.hold!.complete();

      expect((await run)?.saved, isNotNull);
      expect(await rows(), hasLength(1));
    });
  });

  test('run returns how it ended', () async {
    await build();
    runner.errors[0] = failure(TranslationFailureKind.server);
    final failed = await jobs().run(_key, _lines.sublist(0, 5), _en);
    expect(failed?.failure, TranslationFailureKind.server);
    // Failed and not forced: skipped.
    expect(await jobs().run(_key, _lines.sublist(0, 5), _en), isNull);
    final saved = await jobs().run(
      _key,
      _lines.sublist(0, 5),
      _en,
      force: true,
    );
    expect(saved?.saved, isNotNull);
    expect(saved, status()[_key]);
  });
}
