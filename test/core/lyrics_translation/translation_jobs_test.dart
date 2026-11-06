import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:logging/logging.dart';

import '../lyrics/fake_lyrics_readers.dart';
import 'fake_plugin_runner.dart';
import 'fake_translator.dart';

final _plugin = testTranslatePlugin;
const _lines = ['alpha', 'beta', 'gamma'];
final _en = translationLanguageFor('en')!;
final _key = TranslationJobKey('hash', 'en', _plugin);
final _both = {_plugin};

void main() {
  late LibraryDatabase db;
  late FakePluginRunner plugin;
  late ProviderContainer container;

  TranslationJobs jobs() => container.read(translationJobsProvider.notifier);

  Map<TranslationJobKey, TranslationJobStatus> status() =>
      container.read(translationJobsProvider);

  void build({
    bool withDb = true,
    Set<TranslationServiceId>? acknowledged,
    FakeSecretStore? store,
  }) {
    container = translationContainer(
      db: withDb ? db : null,
      lyrics: FakeEmbeddedLyricsReader(),
      plugin: plugin,
      settings: translationSettings(acknowledged: acknowledged ?? _both),
      store: store,
    );
    container.listen(translationJobsProvider, (_, _) {});
    jobs().setCurrent(_key);
  }

  Future<List<LyricTranslationRow>> rows() =>
      db.watchLyricTranslations('hash', 'en').first;

  setUp(() {
    db = memoryDb();
    plugin = FakePluginRunner();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a service whose notice is not accepted is never called', () async {
    build(acknowledged: {});
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en, force: true);
    expect(plugin.calls, isEmpty);
    expect(status(), isEmpty);
    expect(await rows(), isEmpty);
  });

  test('without a database nothing happens', () async {
    build(withDb: false);
    await jobs().run(_key, _lines, _en);
    expect(plugin.calls, isEmpty);
    expect(status(), isEmpty);
  });

  test('too many lines or characters: tooLong, nothing sent', () async {
    build();
    await jobs().run(_key, [for (var i = 0; i < 1001; i++) 'l$i'], _en);
    expect(status()[_key]!.failure, TranslationFailureKind.tooLong);

    final other = TranslationJobKey('hash2', 'en', _plugin);
    await jobs().run(other, [for (var i = 0; i < 11; i++) '$i' * 2000], _en);
    expect(status()[other]!.failure, TranslationFailureKind.tooLong);
    expect(plugin.calls, isEmpty);
  });

  test('a running job is not started twice and is not cancelled', () async {
    build();
    plugin.hold = Completer<void>();
    final first = jobs().run(_key, _lines, _en);
    final second = jobs().run(_key, _lines, _en);
    await until(() => plugin.calls.isNotEmpty);
    expect(status()[_key]!.isRunning, isTrue);

    plugin.hold!.complete();
    await Future.wait([first, second]);
    expect(plugin.calls, hasLength(1));
    expect(status()[_key]!.isRunning, isFalse);
    expect(await rows(), hasLength(1));
  });

  test('a failure waits for retry; force and clearFailure lift it', () async {
    build();
    plugin.errors[0] = failure(TranslationFailureKind.rateLimited);
    await jobs().run(_key, _lines, _en);
    expect(status()[_key]!.failure, TranslationFailureKind.rateLimited);

    await jobs().run(_key, _lines, _en);
    expect(plugin.calls, hasLength(1));

    jobs().clearFailure(_key);
    expect(status(), isEmpty);
    await jobs().run(_key, _lines, _en);
    expect(plugin.calls, hasLength(2));
    expect(await rows(), hasLength(1));

    plugin.errors[2] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en, force: true);
    expect(status()[_key]!.failure, TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en, force: true);
    expect(plugin.calls, hasLength(4));
    expect(status()[_key]!.saved, isNotNull);
  });

  test('a saved row stops a normal run; force replaces it', () async {
    build();
    await jobs().run(_key, _lines, _en);
    await jobs().run(_key, _lines, _en);
    expect(plugin.calls, hasLength(1));

    plugin.transform = (line) => 'new:$line';
    await jobs().run(_key, _lines, _en, force: true);
    expect(plugin.calls, hasLength(2));
    final saved = await rows();
    expect(saved, hasLength(1));
    expect(saved.single.linesJson, contains('new:alpha'));
  });

  test('force starts over instead of resuming', () async {
    build();
    final lines = [for (var i = 0; i < 120; i++) 'line $i'];
    plugin.errors[1] = failure(TranslationFailureKind.server);
    await jobs().run(_key, lines, _en);
    await jobs().run(_key, lines, _en, force: true);
    expect(plugin.calls[2], lines.sublist(0, 50));
  });

  test(
    'lines left as they were or blank are not saved; language kept',
    () async {
      build();
      plugin.transform = (line) => line == 'beta' ? ' BETA ' : '';
      plugin.detected = 'ja';
      await jobs().run(_key, _lines, _en);
      expect(status()[_key]!.failure, TranslationFailureKind.emptyResult);

      plugin.transform = (line) => line == 'beta' ? ' BETA ' : 'tr:$line';
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
    plugin.errors[0] = StateError('Bearer top-secret');
    await jobs().run(_key, _lines, _en);

    expect(status()[_key]!.failure, TranslationFailureKind.invalidResponse);
    expect(records.join(), contains('StateError'));
    expect(records.join(), isNot(contains('top-secret')));
  });

  test('clearFailures forgets the failures of a service', () async {
    build();
    plugin.errors[0] = failure(TranslationFailureKind.server);
    await jobs().run(_key, _lines, _en);
    expect(status(), hasLength(1));

    jobs().clearFailures(_plugin);
    expect(status(), isEmpty);
  });

  test('a job does not run while translation is off', () async {
    container = translationContainer(
      db: db,
      lyrics: FakeEmbeddedLyricsReader(),
      plugin: plugin,
      settings: translationSettings(show: false),
    );
    await jobs().run(_key, _lines, _en, force: true);
    expect(plugin.calls, isEmpty);
  });

  test(
    'a job finishing after the container is gone saves and is quiet',
    () async {
      build();
      plugin.hold = Completer<void>();
      final running = jobs().run(_key, _lines, _en);
      await until(() => plugin.calls.isNotEmpty);
      container.dispose();

      plugin.hold!.complete();
      await running;
      expect(await rows(), hasLength(1));
    },
  );
}
