import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/plugins/lyrics_plugins_provider.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/plugins/translate/plugin_translate_gate.dart'
    show TranslationSuperseded;
import '../lyrics/plugins/translate/plugin_translate_runner.dart'
    show PluginTranslateInfo;
import '../lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import '../lyrics/plugins/store/plugin_config_values.dart'
    show pluginEffectiveField, pluginValueFits;
import '../secrets/secret_store.dart';
import '../settings/settings_provider.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translator.dart';
import 'translation_ai_tune.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_job_work.dart';
import 'translation_language.dart';
import 'plugin_translator.dart';
import 'translation_scope_providers.dart';
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

  /// The job finished and saved lines and settings with this
  /// [translationFingerprint]; the view hides an older row until the row stream
  /// shows this one.
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
  Map<TranslationJobKey, TranslationJobStatus> build() {
    // Jobs read the song choices with `ref.read`, which does not keep the
    // stream running. This listener does, but only while jobs themselves are
    // listened to (the controller watches them); with no listener on jobs the
    // stream pauses and `run` sees the choices as unknown.
    ref.listen(songTranslationOverridesProvider, (_, _) {});
    return const {};
  }

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
  /// one resolved for the song (or that is not known yet) or has no accepted
  /// notice, when the library database is unavailable, or (without [force])
  /// when a usable row is saved already.
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
        readTranslationChoiceFor(ref, key.hash)?.service != key.service ||
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
      final (translator, version, settings) = await _translatorFor(
        key,
        uniqueLines,
        token,
      );
      if (!ref.mounted || !owns()) return null;
      checkJobLimits(uniqueLines, target, translator);
      final resumed = _partial[key];
      if (force ||
          resumed?.version != version ||
          resumed?.settings != settings) {
        _partial.remove(key);
      }
      final partial = _partial.putIfAbsent(
        key,
        () => JobPartial(version, settings),
      );
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
        settingsJson: settings,
      );
      if (map == null) {
        _dropPartial(key, partial);
        return end(
          const TranslationJobStatus.failed(TranslationFailureKind.emptyResult),
        );
      }
      _dropPartial(key, partial);
      return end(
        TranslationJobStatus.saved(translationFingerprint(map, settings)),
      );
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

  /// The translator of the key's service, the version of the plugin it runs
  /// (its `updatedAt`), and the AI settings snapshot to save with the result
  /// (null for a plugin without AI settings, or when they cannot be read).
  /// A plugin that is missing is a `server` failure.
  Future<(LyricsTranslator, int?, String?)> _translatorFor(
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
    // The translate spec of an old record is filled by the startup backfill.
    await ref.read(lyricsPluginsControllerProvider)?.ready;
    final info = await runner.spec(service.value);
    // Both read on every chunk: the user may switch service or turn
    // translation off while a long song waits for its turn.
    bool allowed() {
      if (!ref.mounted) return false;
      final prefs = ref.read(settingsProvider).translation;
      return prefs.show &&
          !needsNoticeFor(prefs, service) &&
          readTranslationChoiceFor(ref, key.hash)?.service == service;
    }

    final (:append, :override, :settings) = await _aiSettings(
      key,
      record,
      info,
    );
    final translator = PluginTranslator(
      service: service,
      runner: runner,
      spec: info.spec,
      jobLines: uniqueLines,
      allowed: allowed,
      stillWanted: () => forcedToken != null
          ? identical(_forced[key], forcedToken)
          : _current == key,
      configAppend: append,
      configOverride: override,
    );
    return (translator, record.updatedAt, settings);
  }

  /// For an `ai-translate` plugin: the winning tier's model and style that fit
  /// the plugin's options (`override`, empty when none or when the stored
  /// config cannot be read), the song's note to add to the instruction
  /// of every chunk, and the snapshot of the settings the job starts with
  /// (read once, so a change made while it runs shows as different). Both
  /// stay empty for other plugins; a failed read of the stored config costs the
  /// snapshot, a failed read of the note costs the note, never the job.
  Future<
    ({
      Map<String, String> append,
      Map<String, Object?> override,
      String? settings,
    })
  >
  _aiSettings(
    TranslationJobKey key,
    LyricsPluginRecord record,
    PluginTranslateInfo info,
  ) async {
    final tune = aiTuneOf(record.kind, info.config);
    if (tune == null) {
      return (
        append: const <String, String>{},
        override: const <String, Object?>{},
        settings: null,
      );
    }
    String? note;
    try {
      final db = ref.read(libraryDatabaseProvider);
      if (db != null) note = await db.songTranslationInstruction(key.hash);
    } on Object catch (e) {
      _log.warning('reading the song instruction failed: ${e.runtimeType}');
    }
    final append = <String, String>{
      if (note != null && note.isNotEmpty) aiInstructionKey: note,
    };
    try {
      final controller = ref.read(lyricsPluginsControllerProvider);
      final stored = controller == null
          ? null
          : await controller.storedConfig(record.installId);
      if (stored == null) {
        return (
          append: append,
          override: const <String, Object?>{},
          settings: null,
        );
      }
      // Only the winning tier's tune, and only while it is this job's service.
      final choice = readTranslationChoiceFor(ref, key.hash);
      final tierTune = choice?.service == key.service
          ? choice!.tune
          : const <String, String>{};
      final override = <String, Object?>{};
      for (final (name, field) in [
        (aiModelKey, tune.model),
        (aiStyleKey, tune.style),
      ]) {
        final value = tierTune[name];
        if (value != null &&
            pluginValueFits(pluginEffectiveField(field, stored), value)) {
          override[name] = value;
        }
      }
      return (
        append: append,
        override: override,
        settings: encodeAiSnapshot(tune, {...stored, ...override}, note),
      );
    } on Object catch (e) {
      // Only the type, never the stored values.
      _log.warning('reading the AI settings failed: ${e.runtimeType}');
      return (
        append: append,
        override: const <String, Object?>{},
        settings: null,
      );
    }
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
