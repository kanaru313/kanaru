import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics_translation/deepl_key_provider.dart';
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
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/secrets/secret_store.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_translator.dart';
import 'loopback_server.dart';

const _text = 'alpha\nbeta\ngamma';
const _other = 'delta\nepsilon';
const _idle = Duration(milliseconds: 700); // well past the debounce
const _both = {LyricsTranslationService.google, LyricsTranslationService.deepl};
const _deeplOnly = {LyricsTranslationService.deepl};

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
    FakeTranslator? google,
    this.deepl,
    AppSettings? settings,
    FakeSecretStore? store,
    this.appLang = 'en',
    List<Override> overrides = const [],
    Duration debounce = testDebounce,
  }) : google = google ?? FakeTranslator(LyricsTranslationService.google) {
    container = translationContainer(
      db: db,
      lyrics: lyrics,
      google: this.google,
      deepl: deepl,
      settings: settings,
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
  final FakeTranslator google;
  final FakeTranslator? deepl;
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

FakeSecretStore _storeWithKey() =>
    FakeSecretStore()..values[deeplApiKeySecret] = 'k' * 36;

AppSettings _deeplSettings({String? target}) => translationSettings(
  service: LyricsTranslationService.deepl,
  acknowledged: _deeplOnly,
  target: target,
);

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
      expect(rig.google.calls, isEmpty);
      rig.dispose();
    });

    test('no database, or no lyrics: unavailable', () async {
      final noDb = Rig(null);
      await noDb.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(noDb.state, isA<TranslationUnavailable>());
      expect(noDb.google.calls, isEmpty);
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

      expect(rig.google.calls, [
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
        expect(rig.google.calls, isEmpty);

        await rig.untilReady();
        await settle(_idle);
        expect(rig.google.calls, [
          ['alpha', 'beta', 'gamma'],
        ]);
        expect(rig.google.targets, ['en']);
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
      expect(again.google.calls, isEmpty);
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
      expect(rig.google.calls, hasLength(1));
      rig.dispose();
    });

    test(
      'a saved row with no lines and another language is not a result',
      () async {
        await _seed(db, _text, 'google', '{}');
        final rig = Rig(db);
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();
        expect(rig.google.calls, hasLength(1));
        expect(_lines(rig.state).first, 'tr:alpha');
        rig.dispose();
      },
    );
  });

  group('services', () {
    test(
      'other service row only: Ready(fromOtherService); retranslate',
      () async {
        final deepl = FakeTranslator(LyricsTranslationService.deepl);
        final rig = Rig(
          db,
          deepl: deepl,
          settings: translationSettings(acknowledged: _both),
        );
        await _seed(db, _text, 'deepl', '{"alpha":"from deepl"}');
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();
        await settle(_idle);

        final ready = rig.state as TranslationReady;
        expect(ready.fromOtherService, isTrue);
        expect(ready.service, LyricsTranslationService.deepl);
        expect(ready.lines.first, 'from deepl');
        expect(rig.google.calls, isEmpty);

        await rig.controller.retranslate();
        await until(
          () =>
              rig.state is TranslationReady &&
              !(rig.state as TranslationReady).fromOtherService,
        );
        expect(rig.google.calls, hasLength(1));
        expect(deepl.calls, isEmpty);
        final rows = await rig.rows(_text);
        expect(rows.map((r) => r.provider).toSet(), {'google', 'deepl'});
        expect(
          rows.firstWhere((r) => r.provider == 'deepl').linesJson,
          '{"alpha":"from deepl"}',
        );
        rig.dispose();
      },
    );

    test('key still loading: Loading, no call; Ready once loaded', () async {
      final store = _storeWithKey()..readGate = Completer<void>();
      final deepl = FakeTranslator(LyricsTranslationService.deepl);
      final rig = Rig(
        db,
        deepl: deepl,
        settings: _deeplSettings(),
        store: store,
      );
      await rig.play('/m/a.mp3', _text);
      await settle(_idle);
      expect(rig.state, isA<TranslationLoading>());
      expect(deepl.calls, isEmpty);

      store.readGate!.complete();
      await rig.untilReady();
      expect(deepl.calls, hasLength(1));
      expect(store.reads, 1);
      rig.dispose();
    });

    test('no key: Failed(noKey), nothing sent', () async {
      final server = await LoopbackServer.start((_) => const Reply(200, '{}'));
      addTearDown(server.close);
      final rig = Rig(
        db,
        settings: _deeplSettings(),
        overrides: [deeplBaseUriProvider.overrideWithValue(server.baseUri)],
      );
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      await settle(_idle);
      expect(
        (rig.state as TranslationFailed).kind,
        TranslationFailureKind.noKey,
      );
      expect(server.requests, isEmpty);
      expect(rig.google.calls, isEmpty);
      // No translator exists without a key, so no request can be made.
      expect(rig.container.read(deeplTranslatorProvider), isNull);
      rig.dispose();
    });

    test('a locked or broken key store is reported, not retried', () async {
      for (final (error, kind) in [
        (
          const SecretStoreException(SecretStoreFailure.locked),
          TranslationFailureKind.keyStoreLocked,
        ),
        (
          const SecretStoreException(SecretStoreFailure.io),
          TranslationFailureKind.keyStoreUnavailable,
        ),
      ]) {
        final store = FakeSecretStore()..readError = error;
        final rig = Rig(db, settings: _deeplSettings(), store: store);
        await rig.play('/m/a.mp3', _text);
        await until(() => rig.state is TranslationFailed);
        await settle(_idle);
        expect((rig.state as TranslationFailed).kind, kind);
        expect(store.reads, 1);
        rig.dispose();
      }
    });

    test('unsupported target: Failed without a request', () async {
      final deepl = FakeTranslator(
        LyricsTranslationService.deepl,
        unsupported: {'vi'},
      );
      final rig = Rig(
        db,
        deepl: deepl,
        settings: _deeplSettings(target: 'vi'),
        store: _storeWithKey(),
      );
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(
        (rig.state as TranslationFailed).kind,
        TranslationFailureKind.unsupportedLanguage,
      );
      expect(deepl.calls, isEmpty);
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
      expect(rig.google.calls, [
        ['delta', 'epsilon'],
      ]);
      expect(await rig.rows(_text), isEmpty);
      rig.dispose();
    });

    test('track change while running: both finish, no mixed lines', () async {
      final rig = Rig(db);
      rig.google.gate = Completer<void>();
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.google.calls.length == 1);

      await rig.play('/m/b.mp3', _other);
      expect(rig.state, isA<TranslationLoading>());
      await until(() => rig.google.calls.length == 2);
      expect(rig.state, isA<TranslationLoading>());

      rig.google.gate!.complete();
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
        expect(rig.google.calls, isEmpty);

        answers.add('ko');
        await rig.untilReady();
        expect(rig.google.targets, ['ko']);
        expect((rig.state as TranslationReady).info.songOverride, 'ko');
        rig.dispose();
      },
    );

    test('set and clear the song target', () async {
      final rig = Rig(db);
      rig.google.detected = 'ko';
      await rig.play('/m/a.mp3', _text);
      await rig.untilReady();

      await rig.controller.setSongTarget('ja');
      await until(() => rig.google.targets.contains('ja'));
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
      expect(rig.google.targets, ['en', 'ja']);
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
        await until(() => rig.google.calls.isNotEmpty);
        expect(rig.google.targets, [expected]);
        rig.dispose();
      }
    });
  });

  group('failures', () {
    test(
      'failure is remembered; retry and the other service call again',
      () async {
        final deepl = FakeTranslator(LyricsTranslationService.deepl);
        final rig = Rig(
          db,
          deepl: deepl,
          settings: translationSettings(acknowledged: _both),
          store: _storeWithKey(),
        );
        rig.google.errors[0] = failure(TranslationFailureKind.quotaExceeded);
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
        expect(rig.google.calls, hasLength(1));

        await rig.controller.retry();
        await rig.untilReady();
        expect(rig.google.calls, hasLength(2));

        // A second song fails, then the other service takes over.
        rig.google.errors[2] = failure(TranslationFailureKind.blocked);
        await rig.play('/m/b.mp3', _other);
        await until(() => rig.state is TranslationFailed);
        expect(rig.controller.useOtherService(), isTrue);
        await until(() => deepl.calls.isNotEmpty);
        expect(rig.google.calls, hasLength(3));
        rig.dispose();
      },
    );

    test('chunk 2 of 3 fails: retry sends only the rest', () async {
      final lines = [
        for (var i = 0; i < 120; i++) 'line ${'$i'.padLeft(3, '0')}',
      ];
      final rig = Rig(db);
      rig.google.errors[1] = failure(TranslationFailureKind.server);
      await rig.play('/m/a.mp3', lines.join('\n'));
      await until(() => rig.state is TranslationFailed);
      expect(rig.google.calls, hasLength(2));

      await rig.controller.retry();
      await rig.untilReady();
      expect(rig.google.calls, hasLength(4));
      expect(rig.google.calls[2], lines.sublist(50, 100));
      expect(rig.google.calls[3], lines.sublist(100));
      expect(_lines(rig.state).first, 'tr:line 000');
      rig.dispose();
    });

    test('an empty result is a failure and saves nothing', () async {
      final rig = Rig(db);
      rig.google.transform = (_) => '';
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
        first.google.detected = 'vi';
        await first.play('/m/a.mp3', _text);
        await until(() => first.state is TranslationSameLanguage);
        expect(await first.rows(_text, 'vi'), hasLength(1));
        first.dispose();

        final again = Rig(db, settings: settings);
        await again.play('/m/a.mp3', _text);
        await until(() => again.state is TranslationSameLanguage);
        await settle(_idle);
        expect(again.google.calls, isEmpty);
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
        LyricsTranslationService.google,
      );
      final target = (rig.state as TranslationNeedsNotice).info.effective;
      await rig.container
          .read(translationJobsProvider.notifier)
          .run(key, ['alpha'], target, force: true);
      await rig.controller.retranslate();
      await rig.controller.retry();
      expect(rig.google.calls, isEmpty);
      expect(rig.container.read(translationJobsProvider), isEmpty);

      rig.settings.acknowledgeTranslationNotice(
        LyricsTranslationService.google,
      );
      await rig.untilReady();
      expect(rig.google.calls, hasLength(1));
      rig.dispose();
    });

    test(
      'useOtherService to an unaccepted service asks for the notice',
      () async {
        final deepl = FakeTranslator(LyricsTranslationService.deepl);
        final rig = Rig(db, deepl: deepl, store: _storeWithKey());
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();

        expect(rig.controller.useOtherService(), isFalse);
        await settle(_idle);
        final prefs = rig.container.read(settingsProvider).translation;
        expect(prefs.service, LyricsTranslationService.google);
        expect(prefs.show, isTrue);
        expect(deepl.calls, isEmpty);

        // The accepted notice switches the service; the saved google row shows
        // meanwhile, and only Retranslate asks DeepL.
        rig.settings.enableTranslation(LyricsTranslationService.deepl);
        await until(
          () =>
              rig.state is TranslationReady &&
              (rig.state as TranslationReady).fromOtherService,
        );
        await settle(_idle);
        expect(deepl.calls, isEmpty);
        await rig.controller.retranslate();
        expect(deepl.calls, hasLength(1));
        rig.dispose();
      },
    );
  });

  group('review fixes', () {
    test('retry after a locked key store reads the key again', () async {
      final store = _storeWithKey()
        ..readError = const SecretStoreException(SecretStoreFailure.locked);
      final deepl = FakeTranslator(LyricsTranslationService.deepl);
      final rig = Rig(
        db,
        deepl: deepl,
        settings: _deeplSettings(),
        store: store,
      );
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(deepl.calls, isEmpty);

      store.readError = null; // unlocked
      await rig.controller.retry();
      await rig.untilReady();
      expect(deepl.calls, hasLength(1));
      rig.dispose();
    });

    test(
      'retranslate shows Loading, then the new row, never the old',
      () async {
        final rig = Rig(db);
        await rig.play('/m/a.mp3', _text);
        await rig.untilReady();
        rig.states.clear();

        rig.google.transform = (line) => 'new:$line';
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

    test('saving a valid key goes on without pressing retry', () async {
      final server = await LoopbackServer.start(
        (_) => const Reply(200, '{"character_count":1,"character_limit":9}'),
      );
      addTearDown(server.close);
      final deepl = FakeTranslator(LyricsTranslationService.deepl);
      final rig = Rig(
        db,
        deepl: deepl,
        settings: _deeplSettings(),
        overrides: [deeplBaseUriProvider.overrideWithValue(server.baseUri)],
      );
      await rig.play('/m/a.mp3', _text);
      await until(() => rig.state is TranslationFailed);
      expect(deepl.calls, isEmpty);

      await rig.container
          .read(deeplApiKeyProvider.notifier)
          .save('abcdefghijabcdefghijabcdefghij:fx');
      await rig.untilReady();
      expect(deepl.calls, hasLength(1));
      rig.dispose();
    });

    test(
      'retranslate and retry do nothing while off or target loads',
      () async {
        final off = Rig(db, settings: translationSettings(show: false));
        await off.play('/m/a.mp3', _text);
        await off.controller.retranslate();
        await off.controller.retry();
        expect(off.google.calls, isEmpty);
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
        expect(loading.google.calls, isEmpty);
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
      expect(rig.google.targets, ['en']);
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
      expect(rig.google.calls, hasLength(1));
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
    CachedTranslation row(LyricsTranslationService s, String text) =>
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
          service: LyricsTranslationService.google,
          lyrics: lyrics,
          rows: rows,
          job: saved,
          deeplKey: null,
        ).state;

    test('a lagging row stream shows Loading, not an older row', () {
      expect(derive([]), isA<TranslationLoading>());
      expect(
        derive([row(LyricsTranslationService.deepl, 'x')]),
        isA<TranslationLoading>(),
      );
      expect(
        derive([row(LyricsTranslationService.google, 'old')]),
        isA<TranslationLoading>(),
      );
      expect(
        (derive([
          row(LyricsTranslationService.google, 'new'),
        ]) as TranslationReady).lines,
        ['new'],
      );
    });
  });
}
