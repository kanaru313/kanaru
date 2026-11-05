import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_content_hash.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_derive.dart';
import 'package:kanaru/core/lyrics_translation/translation_cache.dart';
import 'package:kanaru/core/lyrics_translation/translation_job_work.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

const _text = 'alpha\nbeta\ngamma';
const _other = 'delta\nepsilon';
const _idle = Duration(milliseconds: 700); // well past the debounce

String _hashOfText(String text) => lyricsContentHash(
  Lyrics(
    lines: [for (final t in text.split('\n')) LyricLine(Duration.zero, t)],
    synced: false,
    source: LyricsSource.embedded,
  ),
);

/// A status that always finds [lyrics] for [uri], as an online match does.
class _OnlineStatus extends PlayingLyricsStatusNotifier {
  _OnlineStatus(this.uri, this.lyrics);

  final String uri;
  final Lyrics lyrics;

  @override
  PlayingLyricsStatus? build() => LyricsFound(uri, lyrics);
}

/// One container playing fake lyrics with fake translators.
class Rig {
  Rig(
    this.db, {
    FakePluginRunner? plugin,
    AppSettings? settings,
    FakeSecretStore? store,
    this.appLang = 'en',
    List<Override> overrides = const [],
    Duration debounce = testDebounce,
  }) : plugin = plugin ?? FakePluginRunner() {
    container = translationContainer(
      db: db,
      lyrics: lyrics,
      plugin: this.plugin,
      settings: settings ?? translationSettings(),
      store: store,
      overrides: overrides,
      debounce: debounce,
    );
    sub = container.listen(
      lyricsTranslationProvider(appLang),
      (_, next) => states.add(next),
    );
  }

  final LibraryDatabase? db;
  final FakePluginRunner plugin;
  final String appLang;
  final lyrics = FakeEmbeddedLyricsReader();

  /// Every state the controller moved to, in order.
  final states = <LyricsTranslationState>[];
  late final ProviderContainer container;
  late final ProviderSubscription<LyricsTranslationState> sub;

  LyricsTranslationState get state => sub.read();

  LyricsTranslationController get controller =>
      container.read(lyricsTranslationProvider(appLang).notifier);

  SettingsNotifier get settings => container.read(settingsProvider.notifier);

  Future<void> play(String path, String? text) async {
    if (text != null) lyrics.byPath[path] = (text: text, synced: const []);
    await container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: path, title: path),
    ]);
    await settle();
  }

  Future<List<LyricTranslationRow>> rows(String text, [String target = 'en']) =>
      db!.watchLyricTranslations(_hashOfText(text), target).first;

  Future<void> untilReady() => until(() => state is TranslationReady);

  void dispose() => container.dispose();
}

Future<void> _seed(
  LibraryDatabase db,
  String text,
  String provider,
  String json, {
  String target = 'en',
  String? source = 'ja',
}) => db.saveLyricTranslation(
  LyricTranslationsCompanion.insert(
    contentHash: _hashOfText(text),
    provider: provider,
    targetLang: target,
    sourceLang: Value(source),
    linesJson: json,
    createdAt: 1,
  ),
);

List<String?> _lines(LyricsTranslationState s) => (s as TranslationReady).lines;

void main() {
  late LibraryDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('basics', () {
    test('off: nothing is sent, state carries hash and target', () async {
      final rig = Rig(db, settings: translationSettings(show: false));
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);

      final state = rig.state as TranslationOff;
      expect(state.info.hash, _hashOfText(_text));
      expect(state.info.effective.code, 'en');
      expect(state.info.songOverride, isNull);
      expect(rig.plugin.calls, isEmpty);
      rig.dispose();
    });

    test('no database, or no lyrics: unavailable', () async {
      final noDb = Rig(null);
      await noDb.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(noDb.state, isA<TranslationUnavailable>());
      expect(noDb.plugin.calls, isEmpty);
      noDb.dispose();

      final none = Rig(db);
      await none.play('/m/none.mp3', null);
      expect(none.state, isA<TranslationUnavailable>());
      none.dispose();
    });

    test('lyrics found online are translated like local ones', () async {
      const uri = '/m/online.mp3';
      final rig = Rig(
        db,
        overrides: [
          playingLyricsStatusProvider.overrideWith(
            () => _OnlineStatus(
              uri,
              Lyrics(
                lines: [
                  for (final t in _text.split('\n'))
                    LyricLine(Duration.zero, t),
                ],
                synced: false,
                source: LyricsSource.sidecar,
              ),
            ),
          ),
        ],
      );
      await rig.play(uri, null);
      await rig.untilReady();

      expect(rig.plugin.calls, [
        ['alpha', 'beta', 'gamma'],
      ]);
      expect(_lines(rig.state), ['tr:alpha', 'tr:beta', 'tr:gamma']);
      rig.dispose();
    });

    test(
      'debounce: one call after the delay, two listeners, one call',
      () async {
        final rig = Rig(db);
        final second = rig.container.listen(
          lyricsTranslationProvider('en'),
          (_, _) {},
        );
        await rig.play('/m/a.mp3', _text);
        expect(rig.state, isA<TranslationLoading>());
        expect(rig.plugin.calls, isEmpty);

        await rig.untilReady();
        await settle(_idle);
        expect(rig.plugin.calls, [
          ['alpha', 'beta', 'gamma'],
        ]);
        expect(rig.plugin.targets, ['en']);
        expect(_lines(rig.state), ['tr:alpha', 'tr:beta', 'tr:gamma']);
        expect(second.read(), rig.state);
        expect(await rig.rows(_text), hasLength(1));
        rig.dispose();
      },
    );

    test('the default delay is one second', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(translationDebounceProvider),
        const Duration(seconds: 1),
      );
    });

    test('reopen with the same database: Ready, zero calls', () async {
      final first = Rig(db);
      await first.play('/m/a.mp3', _text);
      await first.untilReady();
      first.dispose();

      final again = Rig(db);
      await again.play('/m/a.mp3', _text);
      await again.untilReady();
      await settle(_idle);
      expect(_lines(again.state), ['tr:alpha', 'tr:beta', 'tr:gamma']);
      expect(again.plugin.calls, isEmpty);
      again.dispose();
    });

    test('equal content after a rebuild is not a change', () async {
      final rig = Rig(db);
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();
      var changes = 0;
      rig.container.listen(
        lyricsTranslationProvider('en'),
        (_, _) => changes++,
      );

      final prefs = rig.container.read(settingsProvider).translation;
      rig.settings.setTranslation(
        prefs.copyWith(display: LyricsTranslationDisplay.replace),
      );
      await settle(_idle);
      expect(changes, 0);
      expect(rig.plugin.calls, hasLength(1));
      rig.dispose();
    });

    test(
      'a saved row with no lines and another language is not a result',
      () async {
        await _seed(db, _text, testTranslatePlugin.value, '{}');
        final rig = Rig(db);
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();
        expect(rig.plugin.calls, hasLength(1));
        expect(_lines(rig.state).first, 'tr:alpha');
        rig.dispose();
      },
    );
  });

  group('services', () {
    test('a row saved by the removed DeepL client is ignored', () async {
      final rig = Rig(db);
      await _seed(db, _text, 'deepl', '{"alpha":"from deepl"}');
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();

      final ready = rig.state as TranslationReady;
      expect(ready.fromOtherService, isFalse);
      expect(ready.service, testTranslatePlugin);
      expect(ready.lines.first, 'tr:alpha');
      expect(rig.plugin.calls, hasLength(1));
      rig.dispose();
    });

    test('unsupported target: Failed without a request', () async {
      final plugin = FakePluginRunner(
        spec_: const PluginTranslateSpec(languages: ['en']),
      );
      final rig = Rig(
        db,
        plugin: plugin,
        settings: translationSettings(target: 'vi'),
      );
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(
        (rig.state as TranslationFailed).kind,
        TranslationFailureKind.unsupportedLanguage,
      );
      expect(plugin.calls, isEmpty);
      rig.dispose();
    });
  });

  group('songs', () {
    test('track change within the delay: no call for the first song', () async {
      final rig = Rig(db, debounce: const Duration(seconds: 2));
      await rig.play('/m/a.mp3', _text);
      await rig.play('/m/b.mp3', _other);
      await rig.untilReady();
      await settle(_idle);
      expect(rig.plugin.calls, [
        ['delta', 'epsilon'],
      ]);
      expect(await rig.rows(_text), isEmpty);
      rig.dispose();
    });

    test('track change while running: both finish, no mixed lines', () async {
      final rig = Rig(db, settings: translationSettings());
      rig.plugin.hold = Completer<void>();
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.plugin.calls.length == 1);

      await rig.play('/m/b.mp3', _other);
      expect(rig.state, isA<TranslationLoading>());
      await settle(_idle);
      expect(rig.state, isA<TranslationLoading>());

      rig.plugin.hold!.complete();
      await rig.untilReady();
      await settle(_idle);
      expect(_lines(rig.state), ['tr:delta', 'tr:epsilon']);
      // Song A's result never reached song B's view.
      for (final state in rig.states) {
        if (state is TranslationReady) {
          expect(state.lines, isNot(contains('tr:alpha')));
          expect(state.info.hash, _hashOfText(_other));
        }
      }
      expect(await rig.rows(_text), hasLength(1));
      expect(await rig.rows(_other), hasLength(1));
      rig.dispose();
    });

    test(
      'per-song target: no request until it answers, then its language',
      () async {
        final answers = StreamController<String?>();
        addTearDown(answers.close);
        final rig = Rig(
          db,
          overrides: [
            songTranslationTargetProvider.overrideWith(
              (ref, hash) => answers.stream,
            ),
          ],
        );
        await rig.play('/m/a.mp3', _text);
        await settle(_idle);
        expect(rig.state, isA<TranslationLoading>());
        expect(rig.plugin.calls, isEmpty);

        answers.add('ko');
        await rig.untilReady();
        expect(rig.plugin.targets, ['ko']);
        expect((rig.state as TranslationReady).info.songOverride, 'ko');
        rig.dispose();
      },
    );

    test('set and clear the song target', () async {
      final rig = Rig(db);
      rig.plugin.detected = 'ko';
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();

      await rig.controller.setSongTarget('ja');
      await until(() => rig.plugin.targets.contains('ja'));
      await until(
        () =>
            rig.state is TranslationReady &&
            (rig.state as TranslationReady).info.effective.code == 'ja',
      );

      await rig.controller.setSongTarget(null);
      await until(
        () =>
            rig.state is TranslationReady &&
            (rig.state as TranslationReady).info.songOverride == null,
      );
      await settle(_idle);
      expect(rig.plugin.targets, ['en', 'ja']);
      rig.dispose();
    });

    test('the default target follows the app language', () async {
      for (final (lang, setting, expected) in [
        ('vi', null, 'vi'),
        ('xx', null, 'en'),
        ('vi', 'ja', 'ja'),
      ]) {
        final rig = Rig(
          db,
          appLang: lang,
          settings: translationSettings(target: setting),
        );
        await rig.play('/m/$lang$setting.mp3', '$lang $setting');
        await until(() => rig.plugin.calls.isNotEmpty);
        expect(rig.plugin.targets, [expected]);
        rig.dispose();
      }
    });
  });

  group('failures', () {
    test('failure is remembered; retry calls again', () async {
      final rig = Rig(db);
      rig.plugin.errors[0] = failure(TranslationFailureKind.quotaExceeded);
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(
        (rig.state as TranslationFailed).kind,
        TranslationFailureKind.quotaExceeded,
      );

      final prefs = rig.container.read(settingsProvider).translation;
      rig.settings.setTranslation(
        prefs.copyWith(display: LyricsTranslationDisplay.replace),
      );
      await settle(_idle);
      expect(rig.plugin.calls, hasLength(1));

      await rig.controller.retry();
      await rig.untilReady();
      expect(rig.plugin.calls, hasLength(2));
      rig.dispose();
    });

    test('chunk 2 of 3 fails: retry sends only the rest', () async {
      final lines = [
        for (var i = 0; i < 120; i++) 'line ${'$i'.padLeft(3, '0')}',
      ];
      final rig = Rig(db);
      rig.plugin.errors[1] = failure(TranslationFailureKind.server);
      await rig.play('/m/a.mp3', lines.join('\n'));
      await until(() => rig.state is TranslationFailed);
      expect(rig.plugin.calls, hasLength(2));

      await rig.controller.retry();
      await rig.untilReady();
      expect(rig.plugin.calls, hasLength(4));
      expect(rig.plugin.calls[2], lines.sublist(50, 100));
      expect(rig.plugin.calls[3], lines.sublist(100));
      expect(_lines(rig.state).first, 'tr:line 000');
      rig.dispose();
    });

    test('an empty result is a failure and saves nothing', () async {
      final rig = Rig(db);
      rig.plugin.transform = (_) => '';
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(
        (rig.state as TranslationFailed).kind,
        TranslationFailureKind.emptyResult,
      );
      expect(await rig.rows(_text), isEmpty);
      rig.dispose();
    });

    test(
      'same language: a note, the row is saved, reopen sends nothing',
      () async {
        final settings = translationSettings(target: 'vi');
        final first = Rig(db, settings: settings);
        first.plugin.detected = 'vi';
        await first.play('/m/a.mp3', _text);
        await until(() => first.state is TranslationSameLanguage);
        expect(await first.rows(_text, 'vi'), hasLength(1));
        first.dispose();

        final again = Rig(db, settings: settings);
        await again.play('/m/a.mp3', _text);
        await until(() => again.state is TranslationSameLanguage);
        await settle(_idle);
        expect(again.plugin.calls, isEmpty);
        again.dispose();
      },
    );
  });

  group('notice', () {
    test('not accepted: NeedsNotice, nothing sent, even by run()', () async {
      final rig = Rig(db, settings: translationSettings(acknowledged: {}));
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(rig.state, isA<TranslationNeedsNotice>());

      final key = TranslationJobKey(
        _hashOfText(_text),
        'en',
        testTranslatePlugin,
      );
      final target = (rig.state as TranslationNeedsNotice).info.effective;
      await rig.container
          .read(translationJobsProvider.notifier)
          .run(key, ['alpha'], target, force: true);
      await rig.controller.retranslate();
      await rig.controller.retry();
      expect(rig.plugin.calls, isEmpty);
      expect(rig.container.read(translationJobsProvider), isEmpty);

      rig.settings.acknowledgeTranslationNotice(testTranslatePlugin);
      await rig.untilReady();
      expect(rig.plugin.calls, hasLength(1));
      rig.dispose();
    });
  });

  group('review fixes', () {
    test(
      'retranslate shows Loading, then the new row, never the old',
      () async {
        final rig = Rig(db);
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();
        rig.states.clear();

        rig.plugin.transform = (line) => 'new:$line';
        await rig.controller.retranslate();
        await until(
          () =>
              rig.state is TranslationReady &&
              _lines(rig.state).first == 'new:alpha',
        );
        await settle(_idle);
        expect(rig.states.first, isA<TranslationLoading>());
        for (final state in rig.states.whereType<TranslationReady>()) {
          expect(state.lines.first, 'new:alpha');
        }
        rig.dispose();
      },
    );

    test(
      'retranslate and retry do nothing while off or target loads',
      () async {
        final off = Rig(db, settings: translationSettings(show: false));
        await off.play('/m/a.mp3', _text);
        await off.controller.retranslate();
        await off.controller.retry();
        expect(off.plugin.calls, isEmpty);
        off.dispose();

        final answers = StreamController<String?>();
        addTearDown(answers.close);
        final loading = Rig(
          db,
          overrides: [
            songTranslationTargetProvider.overrideWith(
              (ref, hash) => answers.stream,
            ),
          ],
        );
        await loading.play('/m/a.mp3', _text);
        await loading.controller.retranslate();
        await loading.controller.retry();
        expect(loading.plugin.calls, isEmpty);
        loading.dispose();
      },
    );

    test('a failing per-song target stream counts as no override', () async {
      final rig = Rig(
        db,
        overrides: [
          songTranslationTargetProvider.overrideWith(
            (ref, hash) => Stream<String?>.error(StateError('db')),
          ),
        ],
      );
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();
      expect(rig.plugin.targets, ['en']);
      rig.dispose();
    });

    test('two app languages watching share one job', () async {
      final rig = Rig(db);
      final other = rig.container.listen(
        lyricsTranslationProvider('xx'),
        (_, _) {},
      );
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();
      await settle(_idle);
      expect(rig.plugin.calls, hasLength(1));
      other.close();
      rig.dispose();
    });
  });

  group('derive after a save', () {
    final en = translationLanguageFor('en')!;
    final info = TranslationTargetInfo(
      hash: 'h',
      effective: en,
      songOverride: null,
      defaultTarget: en,
    );
    const lyrics = Lyrics(
      lines: [LyricLine(Duration.zero, 'a')],
      synced: false,
      source: LyricsSource.embedded,
    );
    CachedTranslation row(TranslationServiceId s, String text) =>
        CachedTranslation(
          service: s,
          targetLang: 'en',
          sourceLang: 'ja',
          lines: {'a': text},
        );
    final saved = TranslationJobStatus.saved(linesFingerprint({'a': 'new'}));

    LyricsTranslationState derive(List<CachedTranslation> rows) =>
        deriveTranslation(
          info: info,
          service: testTranslatePlugin,
          lyrics: lyrics,
          rows: rows,
          job: saved,
        ).state;

    test('a lagging row stream shows Loading, not an older row', () {
      expect(derive([]), isA<TranslationLoading>());
      expect(
        derive([row(testTranslatePlugin, 'old')]),
        isA<TranslationLoading>(),
      );
      expect(
        (derive([
          row(testTranslatePlugin, 'new'),
        ]) as TranslationReady).lines,
        ['new'],
      );
    });
  });

  group('plugin service and song context', () {
    final plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;

    Future<void> playTrack(Rig rig, Track track, {String text = _text}) async {
      rig.lyrics.byPath[track.uri] = (text: text, synced: const []);
      await rig.container.read(playerServiceProvider.notifier).openTracks([
        track,
      ]);
      await settle();
    }

    test(
      'title and artist reach the translator, a file name does not',
      () async {
        final rig = Rig(db);
        await playTrack(
          rig,
          const Track(uri: '/m/a.mp3', title: 'Real Title', artist: ' Band '),
        );
        await rig.untilReady();
        expect(rig.plugin.songs.single?.title, 'Real Title');
        expect(rig.plugin.songs.single?.artist, 'Band');

        await rig.controller.retranslate();
        expect(rig.plugin.songs.last?.title, rig.plugin.songs.first?.title);
        expect(rig.plugin.songs.last?.artist, rig.plugin.songs.first?.artist);
        rig.dispose();

        final named = Rig(db);
        named.plugin.errors[0] = failure(TranslationFailureKind.server);
        await playTrack(
          named,
          const Track(uri: '/m/b.mp3', title: 'b'),
          text: _other,
        );
        await until(() => named.state is TranslationFailed);
        await named.controller.retry();
        await named.untilReady();
        expect(named.plugin.songs, hasLength(2));
        expect(
          named.plugin.songs.every((s) => s?.title == '' && s?.artist == ''),
          isTrue,
        );
        named.dispose();
      },
    );

    test(
      'a plugin that is gone: Off, nothing sent',
      () async {
        final rig = Rig(
          db,
          settings: translationSettings(
            service: plugin,
            acknowledged: {plugin},
          ),
          overrides: [
            translatePluginRecordsProvider.overrideWithValue(
              const AsyncValue.data([]),
            ),
          ],
        );
        await rig.play('/m/a.mp3', _text);
        await settle(_idle);
        expect(rig.state, isA<TranslationOff>());
        expect(rig.plugin.calls, isEmpty);
        rig.dispose();
      },
    );

    test('stored null with show true built by hand: Off, no call', () async {
      final rig = Rig(
        db,
        settings: const AppSettings(
          translation: TranslationPrefs(show: true),
        ),
      );
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(rig.state, isA<TranslationOff>());
      expect(rig.plugin.calls, isEmpty);
      rig.dispose();
    });

    test('switching to a song without lyrics drops the next chunk', () async {
      final runner = FakePluginRunner(
        spec_: const PluginTranslateSpec(languages: ['en'], maxLines: 10),
      );
      final rig = Rig(
        db,
        settings: translationSettings(
          service: plugin,
          acknowledged: {plugin},
        ),
        overrides: [
          pluginTranslateRunnerProvider.overrideWithValue(runner),
          translatePluginRecordsProvider.overrideWithValue(
            AsyncValue.data([translateRecord(plugin.value)]),
          ),
        ],
      );
      runner.hold = Completer<void>();
      await rig.play(
        '/m/a.mp3',
        [for (var i = 0; i < 25; i++) 'line $i'].join('\n'),
      );
      await until(() => runner.calls.isNotEmpty);

      await rig.play('/m/none.mp3', null);
      runner.hold!.complete();
      await settle(_idle);

      expect(runner.calls, hasLength(1));
      rig.dispose();
    });

    test('plugin list still loading: Loading, nothing sent', () async {
      final rig = Rig(
        db,
        settings: translationSettings(
          service: plugin,
          acknowledged: {plugin},
        ),
        overrides: [
          translatePluginRecordsProvider.overrideWithValue(
            const AsyncValue.loading(),
          ),
        ],
      );
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(rig.state, isA<TranslationLoading>());
      expect(rig.plugin.calls, isEmpty);
      rig.dispose();
    });
  });
}
