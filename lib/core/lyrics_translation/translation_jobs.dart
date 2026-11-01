import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/plugins/translate/plugin_translate_gate.dart'
    show TranslationSuperseded;
import '../lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import '../secrets/secret_store.dart';
import '../settings/settings_provider.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translator.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_job_work.dart';
import 'translation_language.dart';
import 'plugin_translator.dart';
import 'translation_providers.dart';
import 'translation_service.dart';
import 'translation_service_resolution.dart';
import 'translation_song_context.dart';

final _log = Logger('translation');

/// One translation: a lyrics text into a language by a service.
@immutable
class TranslationJobKey {
  const TranslationJobKey(this.hash, this.targetCode, this.service);

  final String hash;
  final String targetCode;
  final TranslationServiceId service;

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
  TranslationJobKey? _current;

  @override
  Map<TranslationJobKey, TranslationJobStatus> build() => const {};

  void clearFailure(TranslationJobKey key) {
    if (state[key]?.failure != null) _remove(key);
  }

  /// The job the screen wants now. A plugin chunk still waiting for its turn
  /// is dropped, unsent, when its job is neither this one nor forced.
  void setCurrent(TranslationJobKey? key) => _current = key;

  /// Forgets every remembered failure of [service] and the chunks it had
  /// translated (its key or configuration changed, so old chunks, possibly
  /// empty ones, must not end up in a saved row).
  void clearFailures(TranslationServiceId service) {
    if (!ref.mounted) return;
    _partial.removeWhere((key, _) => key.service == service);
    state = {
      for (final e in state.entries)
        if (e.value.failure == null || e.key.service != service) e.key: e.value,
    };
  }

  /// Translates [uniqueLines] (see `uniqueLineTexts`) into [target].
  ///
  /// Returns at once, sending nothing, when the job runs, when it failed and
  /// [force] is off, when translation is off, the key's service is not the
  /// effective one or has no accepted notice, when the library database is
  /// unavailable, or (without [force]) when a usable row is saved already.
  /// [force] (Retranslate) also starts over instead of resuming the chunks
  /// done before a failure. [song] is context for plugins; Google ignores it.
  ///
  /// A plugin chunk dropped because the screen moved on ends the run without
  /// a failure; the chunks done stay for when the user comes back.
  Future<void> run(
    TranslationJobKey key,
    List<String> uniqueLines,
    TranslationLanguage target, {
    bool force = false,
    TranslationSongContext? song,
  }) async {
    final status = state[key];
    if (status != null &&
        (status.isRunning || (status.failure != null && !force))) {
      return;
    }
    final prefs = ref.read(settingsProvider).translation;
    if (!prefs.show ||
        ref.read(effectiveTranslationServiceProvider) != key.service ||
        needsNoticeFor(prefs, key.service)) {
      return;
    }
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    _set(key, const TranslationJobStatus.running());
    try {
      if (!force && await _hasUsableRow(db, key, target)) {
        _remove(key);
        return;
      }
      if (!ref.mounted) return;
      final (translator, version) = await _translatorFor(
        key,
        uniqueLines,
        force: force,
      );
      if (!ref.mounted) return;
      checkJobLimits(uniqueLines, target, translator);
      if (force || _partial[key]?.version != version) _partial.remove(key);
      final partial = _partial.putIfAbsent(key, () => JobPartial(version));
      await translateMissingLines(
        translator,
        uniqueLines,
        target,
        partial,
        song: song,
      );
      // clearFailures dropped the chunks while this job ran: what it holds
      // may be stale, so nothing is saved.
      if (!identical(_partial[key], partial)) {
        _remove(key);
        return;
      }
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
    } on TranslationSuperseded {
      _remove(key);
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

  /// The translator of the key's service, and the version of the plugin it
  /// runs (its `updatedAt`; `null` for Google). A plugin that is missing is
  /// a `server` failure.
  Future<(LyricsTranslator, int?)> _translatorFor(
    TranslationJobKey key,
    List<String> uniqueLines, {
    required bool force,
  }) async {
    final service = key.service;
    if (service.isGoogle) return (ref.read(googleTranslatorProvider), null);
    final runner = ref.read(pluginTranslateRunnerProvider);
    final record = ref
        .read(translatePluginRecordsProvider)
        .value
        ?.where((r) => r.installId == service.value)
        .firstOrNull;
    if (runner == null || record == null) {
      throw const TranslationException(TranslationFailureKind.server);
    }
    final info = await runner.spec(service.value);
    // Both read on every chunk: the user may switch service or turn
    // translation off while a long song waits for its turn.
    bool allowed() {
      if (!ref.mounted) return false;
      final prefs = ref.read(settingsProvider).translation;
      return prefs.show &&
          !needsNoticeFor(prefs, service) &&
          ref.read(effectiveTranslationServiceProvider) == service;
    }

    final translator = PluginTranslator(
      service: service,
      runner: runner,
      spec: info.spec,
      jobLines: uniqueLines,
      allowed: allowed,
      stillWanted: () => force || _current == key,
    );
    return (translator, record.updatedAt);
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
