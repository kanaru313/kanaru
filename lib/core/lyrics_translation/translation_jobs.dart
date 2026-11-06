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

/// Runs translation jobs: one per [TranslationJobKey] at a time, failures
/// remembered until [clearFailure] or a forced run. Finished jobs leave no
/// status: their result is the saved row.
///
/// A sent chunk is billed, so a job that runs normally is never cancelled and
/// finishes and saves. Only [cancel], for a forced job (Retranslate), drops the
/// chunks not sent yet and the result of the chunk in flight; chunks already
/// done stay for the next run.
class TranslationJobs
    extends Notifier<Map<TranslationJobKey, TranslationJobStatus>> {
  final _partial = <TranslationJobKey, JobPartial>{};

  /// The token of the forced run of each key. A run owns the key's status only
  /// while its token is here, so a cancelled run that ends late (or fails)
  /// cannot touch what a newer run, or the cancel itself, left.
  final _forced = <TranslationJobKey, Object>{};
  TranslationJobKey? _current;

  @override
  Map<TranslationJobKey, TranslationJobStatus> build() => const {};

  void clearFailure(TranslationJobKey key) {
    if (state[key]?.failure != null) _remove(key);
  }

  /// Stops the forced run of [key]: its status goes at once, so the view shows
  /// the older version again, and what is still in flight is dropped. Does
  /// nothing for a job that is not forced.
  void cancel(TranslationJobKey key) {
    if (_forced.remove(key) != null) _remove(key);
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
  /// Returns null at once, sending nothing, when the job runs, when it failed
  /// and [force] is off, when translation is off, the key's service is not the
  /// effective one or has no accepted notice, when the library database is
  /// unavailable, or (without [force]) when a usable row is saved already.
  /// [force] (Retranslate) also starts over instead of resuming the chunks
  /// done before a failure. [song] is context for plugins.
  ///
  /// A plugin chunk dropped because the screen moved on ends the run without
  /// a failure; the chunks done stay for when the user comes back.
  ///
  /// Returns the status the run ended with (`saved` or `failed`), or null when
  /// it did not run, was dropped or was cancelled.
  Future<TranslationJobStatus?> run(
    TranslationJobKey key,
    List<String> uniqueLines,
    TranslationLanguage target, {
    bool force = false,
    TranslationSongContext? song,
  }) async {
    final status = state[key];
    if (status != null &&
        (status.isRunning || (status.failure != null && !force))) {
      return null;
    }
    final prefs = ref.read(settingsProvider).translation;
    if (!prefs.show ||
        ref.read(effectiveTranslationServiceProvider) != key.service ||
        needsNoticeFor(prefs, key.service)) {
      return null;
    }
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return null;
    final token = force ? Object() : null;
    if (token != null) _forced[key] = token;
    // A run that is not forced always owns its status.
    bool owns() => token == null || identical(_forced[key], token);
    TranslationJobStatus? end(TranslationJobStatus result) {
      if (!owns()) return null;
      _set(key, result);
      return result;
    }

    _set(key, const TranslationJobStatus.running());
    JobPartial? held;
    try {
      if (!force && await _hasUsableRow(db, key, target)) {
        _remove(key);
        return null;
      }
      if (!ref.mounted || !owns()) return null;
      final (translator, version) = await _translatorFor(
        key,
        uniqueLines,
        token,
      );
      if (!ref.mounted || !owns()) return null;
      checkJobLimits(uniqueLines, target, translator);
      if (force || _partial[key]?.version != version) _partial.remove(key);
      final partial = _partial.putIfAbsent(key, () => JobPartial(version));
      held = partial;
      await translateMissingLines(
        translator,
        uniqueLines,
        target,
        partial,
        song: song,
      );
      // Cancelled while the last chunk was in flight: nothing is saved (the
      // finally block drops the partial).
      if (!owns()) return null;
      // clearFailures dropped the chunks while this job ran: what it holds
      // may be stale, so nothing is saved.
      if (!identical(_partial[key], partial)) {
        _remove(key);
        return null;
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
        _dropPartial(key, partial);
        return end(
          const TranslationJobStatus.failed(TranslationFailureKind.emptyResult),
        );
      }
      _dropPartial(key, partial);
      return end(TranslationJobStatus.saved(linesFingerprint(map)));
    } on TranslationSuperseded {
      if (owns()) _remove(key);
      return null;
    } on TranslationException catch (e) {
      return end(TranslationJobStatus.failed(e.kind));
    } on SecretStoreException catch (e) {
      return end(TranslationJobStatus.failed(failureKindOfSecretError(e)));
    } on Object catch (e) {
      // Only the type: the message of a transport error may hold headers.
      _log.warning('translation job failed: ${e.runtimeType}');
      return end(
        const TranslationJobStatus.failed(
          TranslationFailureKind.invalidResponse,
        ),
      );
    } finally {
      // A cancelled retranslate leaves no partial: the next forced run starts
      // clean and a normal run finds the saved row. A newer run's is kept.
      if (held != null && !owns()) _dropPartial(key, held);
      if (token != null && identical(_forced[key], token)) _forced.remove(key);
    }
  }

  /// Forgets [partial] after the save, unless a newer run already replaced it
  /// (a cancel during the write lets a new forced run start meanwhile).
  void _dropPartial(TranslationJobKey key, JobPartial partial) {
    if (identical(_partial[key], partial)) _partial.remove(key);
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
  /// runs (its `updatedAt`). A plugin that is missing is a `server` failure.
  Future<(LyricsTranslator, int?)> _translatorFor(
    TranslationJobKey key,
    List<String> uniqueLines,
    Object? forcedToken,
  ) async {
    final service = key.service;
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
      stillWanted: () => forcedToken != null
          ? identical(_forced[key], forcedToken)
          : _current == key,
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
