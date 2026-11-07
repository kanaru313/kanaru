import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/plugins/lyrics_plugins_provider.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/plugins/store/plugin_config_values.dart'
    show pluginEffectiveField, pluginValueFits;
import '../lyrics/plugins/translate/plugin_translate_runner.dart'
    show PluginTranslateInfo;
import '../lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import '../settings/settings_provider.dart';
import 'lyrics_translator.dart';
import 'plugin_translator.dart';
import 'translation_ai_tune.dart';
import 'translation_failure.dart';
import 'translation_scope_providers.dart';
import 'translation_service.dart';
import 'translation_service_resolution.dart';

final _log = Logger('translation');

/// The translator of the service of a job, the version of the plugin it runs
/// (its `updatedAt`), and the AI settings snapshot to save with the result
/// (null for a plugin without AI settings, or when they cannot be read).
typedef JobTranslator = (LyricsTranslator, int?, String?);

/// Builds the [JobTranslator] for the job of lyrics [hash] by [service].
/// [stillWanted] is asked when a chunk reaches the front of the plugin gate;
/// a chunk that is not wanted then is dropped unsent. A plugin that is
/// missing is a `server` failure.
Future<JobTranslator> translatorForJob(
  Ref ref, {
  required String hash,
  required TranslationServiceId service,
  required List<String> uniqueLines,
  required bool Function() stillWanted,
}) async {
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
        readTranslationChoiceFor(ref, hash)?.service == service;
  }

  final (:append, :override, :settings) = await _aiSettings(
    ref,
    hash,
    service,
    record,
    info,
  );
  final translator = PluginTranslator(
    service: service,
    runner: runner,
    spec: info.spec,
    jobLines: uniqueLines,
    allowed: allowed,
    stillWanted: stillWanted,
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
  Ref ref,
  String hash,
  TranslationServiceId service,
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
    if (db != null) note = await db.songTranslationInstruction(hash);
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
    final choice = readTranslationChoiceFor(ref, hash);
    final tierTune = choice?.service == service
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
