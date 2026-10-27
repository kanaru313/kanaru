import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/secrets/secret_store.dart';
import 'package:logging/logging.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_translator.dart';

const _google = LyricsTranslationService.google;
const _deepl = LyricsTranslationService.deepl;
const _lines = ['alpha', 'beta', 'gamma'];
final _en = translationLanguageFor('en')!;
const _key = TranslationJobKey('hash', 'en', _google);
const _both = {_google, _deepl};

void main() {
  late LibraryDatabase db;
  late FakeTranslator google;
  late FakeTranslator deepl;
  late ProviderContainer container;

  TranslationJobs jobs() => container.read(translationJobsProvider.notifier);

  Map<TranslationJobKey, TranslationJobStatus> status() =>
      container.read(translationJobsProvider);

  void build({
    bool withDb = true,
    bool withDeepl = true,
    Set<LyricsTranslationService> acknowledged = _both,
    FakeSecretStore? store,
  }) {
    container = translationContainer(
      db: withDb ? db : null,
      lyrics: FakeEmbeddedLyricsReader(),
      google: google,
      deepl: withDeepl ? deepl : null,
      settings: translationSettings(acknowledged: acknowledged),
      store: store,
    );
    container.listen(translationJobsProvider, (_, _) {});
  }

  Future<List<LyricTranslationRow>> rows() =>
      db.watchLyricTranslations('hash', 'en').first;

  setUp(() {
    db = memoryDb();
    google = FakeTranslator(_google);
    deepl = FakeTranslator(_deepl);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a service whose notice is not accepted is never called', () async {
    build(acknowledged: {});
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en, force: true);
    expect(google.calls, isEmpty);
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);
  });

  test('only the accepted service runs', () async {
    build(acknowledged: {_google});
    await jobs().run(
      const TranslationJobKey('hash', 'en', _deepl),
      _lines,
      _en,
    );
    expect(deepl.calls, isEmpty);
  });

  test('without a database nothing happens', () async {
    build(withDb: false);
    await jobs().run(_key, _lines, _en);
    expect(google.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test('too many lines or characters: tooLong, nothing sent', () async {
    build();
    await jobs().run(_key, [for (var i = 0; i < 1001; i++) 'l$i'], _en);
    expect(status()[_key]!.failure, TranslationFailureKind.tooLong);

    const other = TranslationJobKey('hash2', 'en', _google);
    await jobs().run(other, [for (var i = 0; i < 11; i++) '$i' * 2000], _en);
    expect(status()[other]!.failure, TranslationFailureKind.tooLong);
    expect(google.calls, isEmpty);
  });

  test('a running job is not started twice and is not cancelled', () async {
    build();
    google.gate = Completer<void>();
    final first = jobs().run(_key, _lines, _en);
    final second = jobs().run(_key, _lines, _en);
    await until(() => google.calls.isNotEmpty);
    expect(status()[_key]!.isRunning, isTrue);

    google.gate!.complete();
    await Future.wait([first, second]);
    expect(google.calls, hasLength(1));
    expect(status()[_key]!.isRunning, isFalse);
    expect(await rows(), hasLength(1));
  });

  test('a failure waits for retry; force and clearFailure lift it', () async {
    build();
    google.errors[0] = failure(TranslationFailureKind.rateLimited);
    await jobs().run(_key, _lines, _en);
    expect(status()[_key]!.failure, TranslationFailureKind.rateLimited);

    await jobs().run(_key, _lines, _en);
    expect(google.calls, hasLength(1));

    jobs().clearFailure(_key);
    expect(status(), isEmpty);
    await jobs().run(_key, _lines, _en);
    expect(google.calls, hasLength(2));
    expect(await rows(), hasLength(1));

    google.errors[2] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en, force: true);
    expect(status()[_key]!.failure, TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en, force: true);
    expect(google.calls, hasLength(4));
    expect(status()[_key]!.saved, isNotNull);
  });

  test('a saved row stops a normal run; force replaces it', () async {
    build();
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en);
    expect(google.calls, hasLength(1));

    google.transform = (line) => 'new:$line';
    await jobs().run(_key, _lines, _en, force: true);
    expect(google.calls, hasLength(2));
    final saved = await rows();
    expect(saved, hasLength(1));
    expect(saved.single.linesJson, contains('new:alpha'));
  });

  test('force starts over instead of resuming', () async {
    build();
    final lines = [for (var i = 0; i < 120; i++) 'line $i'];
    google.errors[1] = failure(TranslationFailureKind.server);
    await jobs().run(_key, lines, _en);
    await jobs().run(_key, lines, _en, force: true);
    expect(google.calls[2], lines.sublist(0, 50));
  });

  test(
    'lines left as they were or blank are not saved; language kept',
    () async {
      build();
      google.transform = (line) => line == 'beta' ? ' BETA ' : '';
      google.detected = 'ja';
      await jobs().run(_key, _lines, _en);
      expect(status()[_key]!.failure, TranslationFailureKind.emptyResult);

      google.transform = (line) => line == 'beta' ? ' BETA ' : 'tr:$line';
      jobs().clearFailure(_key);
      await jobs().run(_key, _lines, _en);
      final row = (await rows()).single;
      expect(row.sourceLang, 'ja');
      expect(row.linesJson, '{"alpha":"tr:alpha","gamma":"tr:gamma"}');
    },
  );

  test('a service error is mapped, the message is never logged', () async {
    build();
    final records = <String>[];
    final sub = Logger.root.onRecord.listen((r) => records.add(r.message));
    addTearDown(sub.cancel);
    google.errors[0] = StateError('Bearer top-secret');
    await jobs().run(_key, _lines, _en);

    expect(status()[_key]!.failure, TranslationFailureKind.invalidResponse);
    expect(records.join(), contains('StateError'));
    expect(records.join(), isNot(contains('top-secret')));
  });

  test('DeepL: no key, locked and broken stores', () async {
    const deeplKey = TranslationJobKey('hash', 'en', _deepl);
    build(withDeepl: false);
    await jobs().run(deeplKey, _lines, _en);
    expect(status()[deeplKey]!.failure, TranslationFailureKind.noKey);
    container.dispose();

    for (final (kind, expected) in [
      (SecretStoreFailure.locked, TranslationFailureKind.keyStoreLocked),
      (
        SecretStoreFailure.noDefaultCollection,
        TranslationFailureKind.keyStoreUnavailable,
      ),
      (
        SecretStoreFailure.unavailable,
        TranslationFailureKind.keyStoreUnavailable,
      ),
      (SecretStoreFailure.timeout, TranslationFailureKind.keyStoreUnavailable),
      (SecretStoreFailure.io, TranslationFailureKind.keyStoreUnavailable),
    ]) {
      build(store: FakeSecretStore()..readError = SecretStoreException(kind));
      await jobs().run(deeplKey, _lines, _en);
      expect(status()[deeplKey]!.failure, expected, reason: kind.name);
      expect(deepl.calls, isEmpty);
      container.dispose();
    }
    build();
  });

  test('google never reads the secret store', () async {
    final store = FakeSecretStore();
    build(store: store);
    await jobs().run(_key, _lines, _en);
    expect(store.reads, 0);
  });

  test('clearFailures forgets one service only', () async {
    build();
    const deeplKey = TranslationJobKey('hash', 'en', _deepl);
    google.errors[0] = failure(TranslationFailureKind.server);
    deepl.errors[0] = failure(TranslationFailureKind.badKey);
    await jobs().run(_key, _lines, _en);
    await jobs().run(deeplKey, _lines, _en);
    expect(status(), hasLength(2));

    jobs().clearFailures(_deepl);
    expect(status().keys, [_key]);
  });

  test('a job does not run while translation is off', () async {
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      google: google,
      settings: translationSettings(show: false),
    );
    await jobs().run(_key, _lines, _en, force: true);
    expect(google.calls, isEmpty);
  });

  test(
    'a job finishing after the container is gone saves and is quiet',
    () async {
      build();
      google.gate = Completer<void>();
      final running = jobs().run(_key, _lines, _en);
      await until(() => google.calls.isNotEmpty);
      container.dispose();

      google.gate!.complete();
      await running;
      expect(await rows(), hasLength(1));
    },
  );
}
