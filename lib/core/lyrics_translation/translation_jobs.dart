import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../secrets/secret_store.dart';
import '../settings/settings_provider.dart';
import 'deepl_key_provider.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translator.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_job_work.dart';
import 'translation_language.dart';
import 'translation_providers.dart';
import 'translation_service.dart';

final _log = Logger('translation');

/// One translation: a lyrics text into a language by a service.
@immutable
class TranslationJobKey {
  const TranslationJobKey(this.hash, this.targetCode, this.service);

  final String hash;
  final String targetCode;
  final LyricsTranslationService service;

  @override
  bool operator ==(Object other) =>
      other is TranslationJobKey &&
      other.hash == hash &&
      other.targetCode == targetCode &&
      other.service == service;

  @override
  int get hashCode => Object.hash(hash, targetCode, service);
}

/// A job that is running, or that failed and waits for Retry.
@immutable
class TranslationJobStatus {
  const TranslationJobStatus.running() : failure = null, saved = null;
  const TranslationJobStatus.failed(TranslationFailureKind this.failure)
    : saved = null;

  /// The job finished and saved lines with this [linesFingerprint]; the view
  /// hides an older row until the row stream shows this one.
  const TranslationJobStatus.saved(int this.saved) : failure = null;

  final TranslationFailureKind? failure;
  final int? saved;

  bool get isRunning => failure == null && saved == null;

  @override
  bool operator ==(Object other) =>
      other is TranslationJobStatus &&
      other.failure == failure &&
      other.saved == saved;

  @override
  int get hashCode => Object.hash(failure, saved);
}

/// Runs translation jobs: one per [TranslationJobKey] at a time, never
/// cancelled (a sent chunk is billed, so a started job finishes and saves),
/// failures remembered until [clearFailure] or a forced run. Finished jobs
/// leave no status: their result is the saved row.
class TranslationJobs
    extends Notifier<Map<TranslationJobKey, TranslationJobStatus>> {
  final _partial = <TranslationJobKey, JobPartial>{};

  @override
  Map<TranslationJobKey, TranslationJobStatus> build() => const {};

  void clearFailure(TranslationJobKey key) {
    if (state[key]?.failure != null) _remove(key);
  }

  /// Forgets every remembered failure of [service] (its key changed).
  void clearFailures(LyricsTranslationService service) {
    if (!ref.mounted) return;
    state = {
      for (final e in state.entries)
        if (e.value.failure == null || e.key.service != service) e.key: e.value,
    };
  }

  /// Translates [uniqueLines] (see `uniqueLineTexts`) into [target].
  ///
  /// Returns at once, sending nothing, when the job runs, when it failed and
  /// [force] is off, when the key's service has no accepted notice, when the
  /// library database is unavailable, or (without [force]) when a usable row
  /// is saved already. [force] (Retranslate) also starts over instead of
  /// resuming the chunks done before a failure.
  Future<void> run(
    TranslationJobKey key,
    List<String> uniqueLines,
    TranslationLanguage target, {
    bool force = false,
  }) async {
    final status = state[key];
    if (status != null &&
        (status.isRunning || (status.failure != null && !force))) {
      return;
    }
    final prefs = ref.read(settingsProvider).translation;
    if (!prefs.show || !prefs.noticeAcknowledged.contains(key.service)) return;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    _set(key, const TranslationJobStatus.running());
    try {
      if (!force && await _hasUsableRow(db, key, target)) {
        _remove(key);
        return;
      }
      if (!ref.mounted) return;
      final translator = await _translatorFor(key.service);
      if (translator == null) return;
      checkJobLimits(uniqueLines, target, translator);
      if (force) _partial.remove(key);
      final partial = _partial.putIfAbsent(key, JobPartial.new);
      await translateMissingLines(translator, uniqueLines, target, partial);
      final map = await saveJobResult(
        db,
        key.hash,
        key.service,
        uniqueLines,
        target,
        partial,
      );
      if (map == null) {
        _partial.remove(key);
        _set(
          key,
          const TranslationJobStatus.failed(TranslationFailureKind.emptyResult),
        );
        return;
      }
      _partial.remove(key);
      _set(key, TranslationJobStatus.saved(linesFingerprint(map)));
    } on TranslationException catch (e) {
      _set(key, TranslationJobStatus.failed(e.kind));
    } on SecretStoreException catch (e) {
      _set(key, TranslationJobStatus.failed(failureKindOfSecretError(e)));
    } on Object catch (e) {
      // Only the type: the message of a transport error may hold headers.
      _log.warning('translation job failed: ${e.runtimeType}');
      _set(
        key,
        const TranslationJobStatus.failed(
          TranslationFailureKind.invalidResponse,
        ),
      );
    }
  }

  Future<bool> _hasUsableRow(
    LibraryDatabase db,
    TranslationJobKey key,
    TranslationLanguage target,
  ) async {
    final rows = await db
        .watchLyricTranslations(key.hash, key.targetCode)
        .first;
    return rows
        .map(decodeTranslationRow)
        .any(
          (c) =>
              c != null &&
              c.service == key.service &&
              isUsableTranslation(c, target),
        );
  }

  /// `null` when the container went away while the key loaded.
  Future<LyricsTranslator?> _translatorFor(
    LyricsTranslationService service,
  ) async {
    if (service == LyricsTranslationService.google) {
      return ref.read(googleTranslatorProvider);
    }
    await ref.read(deeplApiKeyProvider.future);
    if (!ref.mounted) return null;
    final translator = ref.read(deeplTranslatorProvider);
    if (translator == null) {
      throw const TranslationException(TranslationFailureKind.noKey);
    }
    return translator;
  }

  void _set(TranslationJobKey key, TranslationJobStatus status) {
    if (ref.mounted) state = {...state, key: status};
  }

  void _remove(TranslationJobKey key) {
    if (ref.mounted) state = {...state}..remove(key);
  }
}

final translationJobsProvider =
    NotifierProvider<
      TranslationJobs,
      Map<TranslationJobKey, TranslationJobStatus>
    >(TranslationJobs.new);
