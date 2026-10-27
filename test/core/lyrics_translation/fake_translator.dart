import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart' show pumpEventQueue;
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics_translation/deepl_key_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translator.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/secrets/secret_store_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../lyrics/fake_lyrics_readers.dart';
import '../player/fake_audio_backend.dart';

/// A translator that records every call and answers from a script.
class FakeTranslator implements LyricsTranslator {
  FakeTranslator(
    this.service, {
    this.detected = 'ja',
    this.unsupported = const {},
  });

  @override
  final LyricsTranslationService service;

  /// Language reported for every line; `null` reports none.
  String? detected;

  /// Target codes this translator refuses.
  final Set<String> unsupported;

  /// The lines of each call, in order.
  final calls = <List<String>>[];

  /// The target code of each call.
  final targets = <String>[];

  /// Call index (from 0) to the error that call throws.
  final errors = <int, Object>{};

  /// Waited for before answering, to hold a job open.
  Completer<void>? gate;

  /// What a line becomes; an empty string models "no translation".
  String Function(String line) transform = (line) => 'tr:$line';

  @override
  bool supports(TranslationLanguage language) =>
      !unsupported.contains(language.code);

  @override
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    String? context,
  }) async {
    final index = calls.length;
    calls.add(List.of(lines));
    targets.add(target.code);
    await gate?.future;
    final error = errors[index];
    if (error != null) throw error;
    return TranslatedLines(
      [for (final line in lines) transform(line)],
      [for (final _ in lines) detected],
    );
  }
}

TranslationException failure(TranslationFailureKind kind) =>
    TranslationException(kind);

LibraryDatabase memoryDb() => LibraryDatabase(NativeDatabase.memory());

/// Settings with translation on and the notice accepted for [acknowledged].
AppSettings translationSettings({
  bool show = true,
  LyricsTranslationService service = LyricsTranslationService.google,
  Set<LyricsTranslationService> acknowledged = const {
    LyricsTranslationService.google,
  },
  String? target,
}) => AppSettings(
  translation: TranslationPrefs(
    show: show,
    service: service,
    noticeAcknowledged: acknowledged,
  ).withTargetLanguage(target),
);

/// A container that plays local files whose lyrics are in [lyrics] (path to
/// plain text) and translates with the fakes only.
ProviderContainer translationContainer({
  required LibraryDatabase? db,
  required FakeEmbeddedLyricsReader lyrics,
  FakeTranslator? google,
  FakeTranslator? deepl,
  AppSettings? settings,
  SecretStore? store,
  List<Override> overrides = const [],
  Duration debounce = testDebounce,
}) {
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      embeddedLyricsReaderProvider.overrideWithValue(lyrics),
      lrcSidecarReaderProvider.overrideWithValue(FakeLrcSidecarReader()),
      libraryDatabaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(
        settings ?? translationSettings(),
      ),
      if (google != null) googleTranslatorProvider.overrideWithValue(google),
      if (deepl != null) deeplTranslatorProvider.overrideWithValue(deepl),
      secretStoreProvider.overrideWith(
        (ref) async => ResolvedSecretStore(
          store ?? MemorySecretStore(),
          usingFallback: false,
          persistent: false,
        ),
      ),
      translationDebounceProvider.overrideWithValue(debounce),
      ...overrides,
    ],
  );
  container.listen(playerServiceProvider, (_, _) {});
  return container;
}

/// A secret store that counts reads, can fail and can be held open.
class FakeSecretStore implements SecretStore {
  final values = <String, String>{};
  int reads = 0;
  int writes = 0;
  Object? readError;

  /// Reads wait for this before answering.
  Completer<void>? readGate;

  /// Writes wait for this before storing.
  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async {
    reads++;
    await readGate?.future;
    final error = readError;
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await writeGate?.future;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Debounce used by the tests (the app uses one second).
const testDebounce = Duration(milliseconds: 250);

/// Waits until [condition] holds; fails after [timeout] (real time).
Future<void> until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Lets everything that is ready run, and [time] pass.
Future<void> settle([Duration time = Duration.zero]) async {
  await Future<void>.delayed(time);
  await pumpEventQueue();
}
