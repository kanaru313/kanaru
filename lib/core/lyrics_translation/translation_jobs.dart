import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/plugins/translate/plugin_translate_gate.dart'
    show TranslationSuperseded;
import '../secrets/secret_store.dart';
import '../settings/settings_provider.dart';
import 'lyrics_translation_derive.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_job_work.dart';
import 'translation_language.dart';
import 'translation_job_translator.dart';
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

/// How a background run (queue prefetch) ended.
enum BackgroundRunResult { saved, skipped, superseded, failed }

/// Failures of a whole service rather than of one song: the background stops
/// asking that service after one of them.
const _serviceLevelFailures = {
  TranslationFailureKind.noKey,
  TranslationFailureKind.badKey,
  TranslationFailureKind.quotaExceeded,
  TranslationFailureKind.rateLimited,
  TranslationFailureKind.needsConfig,
  TranslationFailureKind.keyStoreLocked,
  TranslationFailureKind.keyStoreUnavailable,
};

enum _Stop { skipped, superseded }

/// How a run ended: the status it left, or why it left none.
typedef _RunEnd = ({TranslationJobStatus? status, _Stop? stop});

const _RunEnd _skipped = (status: null, stop: _Stop.skipped);
const _RunEnd _superseded = (status: null, stop: _Stop.superseded);

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
  var _prefetch = <TranslationJobKey>{};

  /// Background failures remembered for the whole session, by job and the AI
  /// settings snapshot it ran with: the same job is not tried again in the
  /// background unless its settings change.
  final _backgroundTried = <(TranslationJobKey, String?)>{};

  /// Services whose background jobs stopped after a failure of the whole
  /// service (key, quota, rate limit, configuration).
  final _brokenServices = <TranslationServiceId>{};

  /// Bumped by [clearFailures] for a service. A background job that started
  /// before the bump does not record its failure: it ran with the old key or
  /// configuration, so it must not break the service again.
  final _serviceEpoch = <TranslationServiceId, int>{};

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

  /// The job the screen wants now, or null.
  TranslationJobKey? get currentKey => _current;

  /// Whether the job of [currentKey] runs now.
  bool get currentRunning {
    final current = _current;
    return current != null && state[current]?.isRunning == true;
  }

  /// Replaces the set of jobs the queue prefetch wants. A background chunk
  /// still waiting for its turn is dropped, unsent, when its key left the
  /// set; a chunk already in flight finishes and its lines are kept for the
  /// next run, so they are not sent again.
  void setPrefetch(Set<TranslationJobKey> keys) => _prefetch = {...keys};

  /// Forgets every remembered failure of [service] and the chunks it had
  /// translated (its key or configuration changed, so old chunks, possibly
  /// empty ones, must not end up in a saved row).
  void clearFailures(TranslationServiceId service) {
    if (!ref.mounted) return;
    _partial.removeWhere((key, _) => key.service == service);
    _backgroundTried.removeWhere((e) => e.$1.service == service);
    _brokenServices.remove(service);
    _serviceEpoch.update(service, (e) => e + 1, ifAbsent: () => 1);
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
    final db = _startDb(key);
    if (db == null) return null;
    final end = await _execute(
      db,
      key,
      uniqueLines,
      target,
      force: force,
      song: song,
    );
    return end.status;
  }

  /// Translates [uniqueLines] for a song that is not on screen (the queue
  /// prefetch), never forced and never showing a failure.
  ///
  /// While it runs the key's status is `running`, so a normal [run] of the
  /// same key returns null and the screen shows "translating". The result:
  /// - [BackgroundRunResult.skipped]: nothing was sent. The key has a
  ///   status (running, failed or just saved), a usable row is saved,
  ///   translation is off, the key's service is not the one resolved for
  ///   the song (or the choices are not known),
  ///   its notice is not accepted, the database is unavailable, this key
  ///   already failed in the background with the same settings, or the
  ///   service broke earlier in the session.
  /// - [BackgroundRunResult.saved]: the row is saved, as a normal run does.
  /// - [BackgroundRunResult.superseded]: a chunk was dropped unsent because
  ///   the job is no longer wanted (see [setPrefetch]). Chunks done stay and
  ///   the job is not counted as tried.
  /// - [BackgroundRunResult.failed]: nothing is shown. The key and its
  ///   settings are remembered so the background does not retry them, and a
  ///   failure of the whole service (key, quota, rate limit, configuration)
  ///   stops background jobs of that service until [clearFailures]. Chunks
  ///   done stay, and a normal run of the song later tries once more.
  ///
  /// The job is wanted while it is the current one, or while it is in the
  /// prefetch set and the current job is not running; a song that becomes
  /// current meanwhile keeps its job and does not resend the chunks done.
  Future<BackgroundRunResult> runBackground(
    TranslationJobKey key,
    List<String> uniqueLines,
    TranslationLanguage target, {
    TranslationSongContext? song,
  }) async {
    if (state.containsKey(key) || _brokenServices.contains(key.service)) {
      return BackgroundRunResult.skipped;
    }
    final db = _startDb(key);
    if (db == null) return BackgroundRunResult.skipped;
    final end = await _execute(
      db,
      key,
      uniqueLines,
      target,
      song: song,
      background: true,
    );
    final status = end.status;
    if (status == null) {
      return end.stop == _Stop.superseded
          ? BackgroundRunResult.superseded
          : BackgroundRunResult.skipped;
    }
    return status.failure != null
        ? BackgroundRunResult.failed
        : BackgroundRunResult.saved;
  }

  /// The library database when a job of [key] may start: translation is on,
  /// the key's service is the one resolved for the song and has its notice
  /// accepted. Null otherwise.
  LibraryDatabase? _startDb(TranslationJobKey key) {
    final prefs = ref.read(settingsProvider).translation;
    if (!prefs.show ||
        readTranslationChoiceFor(ref, key.hash)?.service != key.service ||
        needsNoticeFor(prefs, key.service)) {
      return null;
    }
    return ref.read(libraryDatabaseProvider);
  }

  /// Whether a chunk of the job of [key] is still worth sending now.
  bool _backgroundWanted(TranslationJobKey key) =>
      _current == key || (_prefetch.contains(key) && !_currentRunning(key));

  /// Whether the job of the current key runs and is not [key] itself: the
  /// song on screen comes first, so a background chunk waits no longer.
  bool _currentRunning(TranslationJobKey key) {
    final current = _current;
    return current != null &&
        current != key &&
        state[current]?.isRunning == true;
  }

  /// A background job of [key] failed: remember it, and for a failure of the
  /// whole service stop every background job of that service.
  void _backgroundFailed(
    TranslationJobKey key,
    String? settings,
    TranslationFailureKind kind,
  ) {
    _backgroundTried.add((key, settings));
    if (_serviceLevelFailures.contains(kind)) _brokenServices.add(key.service);
  }

  /// The run shared by [run] and [runBackground]. A [background] run is never
  /// forced, owns its status as a normal run does, and ends a failure by
  /// removing the status instead of keeping it.
  Future<_RunEnd> _execute(
    LibraryDatabase db,
    TranslationJobKey key,
    List<String> uniqueLines,
    TranslationLanguage target, {
    bool force = false,
    bool background = false,
    TranslationSongContext? song,
  }) async {
    final token = force ? Object() : null;
    if (token != null) _forced[key] = token;
    // A run that is not forced always owns its status.
    bool owns() => token == null || identical(_forced[key], token);
    String? settings;
    final epoch = _serviceEpoch[key.service];
    _RunEnd end(TranslationJobStatus result) {
      if (!owns()) return _skipped;
      if (background && result.failure != null) {
        if (_serviceEpoch[key.service] == epoch) {
          _backgroundFailed(key, settings, result.failure!);
        }
        _remove(key);
      } else {
        _set(key, result);
      }
      return (status: result, stop: null);
    }

    _set(key, const TranslationJobStatus.running());
    JobPartial? held;
    try {
      if (!force && await _hasUsableRow(db, key, target)) {
        _remove(key);
        return _skipped;
      }
      if (!ref.mounted || !owns()) return _skipped;
      final (translator, version, snapshot) = await translatorForJob(
        ref,
        hash: key.hash,
        service: key.service,
        uniqueLines: uniqueLines,
        stillWanted: () => token != null
            ? identical(_forced[key], token)
            : background
            ? _backgroundWanted(key)
            : _current == key,
      );
      settings = snapshot;
      if (!ref.mounted || !owns()) return _skipped;
      if (background && _backgroundTried.contains((key, settings))) {
        _remove(key);
        return _skipped;
      }
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
      if (!owns()) return _skipped;
      // clearFailures dropped the chunks while this job ran: what it holds
      // may be stale, so nothing is saved.
      if (!identical(_partial[key], partial)) {
        _remove(key);
        return _superseded;
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
      return _superseded;
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
