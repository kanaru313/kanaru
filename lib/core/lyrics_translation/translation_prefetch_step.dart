import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/lyrics.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/track_lyrics_preview_provider.dart';
import '../settings/settings_provider.dart';
import 'lyrics_content_hash.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translation_state.dart';
import 'translation_cache.dart';
import 'translation_jobs.dart';
import 'translation_language.dart';
import 'translation_request_inputs.dart';
import 'translation_scope_providers.dart';
import 'translation_service_resolution.dart';

/// A song's job as the queue prefetch sees it once its lyrics are read.
typedef PrefetchCandidate = ({
  TranslationJobKey key,
  TranslationLanguage target,

  /// Whether a request is needed: nothing usable is saved for the song.
  bool needsRequest,
});

/// The filter steps for one song of the queue whose [lyrics] are known: the
/// language, the service choice (the same rule as the playing song, by the
/// scope precedence), the accepted notice and the saved rows. Null when the
/// song cannot be translated now (no database, choice unknown or off, notice
/// missing). Never changes the user's own choices.
Future<PrefetchCandidate?> prefetchCandidateFor(
  Ref ref,
  String appLang,
  Lyrics lyrics,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return null;
  final hash = lyricsContentHashOf(lyrics);
  final prefs = ref.read(settingsProvider).translation;
  final defaultTarget = defaultTranslationTarget(prefs, appLang);
  String? songOverride;
  try {
    songOverride = await db.watchSongTranslationTarget(hash).first;
  } on Object {
    // A failed read counts as no language of its own, as for the screen.
  }
  final target = effectiveTranslationTarget(defaultTarget, songOverride);
  final choice = readTranslationChoiceFor(ref, hash);
  final service = choice?.service;
  if (choice == null || service == null || needsNoticeFor(prefs, service)) {
    return null;
  }
  final key = TranslationJobKey(hash, target.code, service);
  final rows = [
    for (final row in await db.watchLyricTranslations(hash, target.code).first)
      ?decodeTranslationRow(row),
  ];
  final plugins = translationPluginSets(ref.read(lyricsPluginRecordsProvider));
  final derived = deriveTranslation(
    info: TranslationTargetInfo(
      hash: hash,
      effective: target,
      songOverride: songOverride,
      defaultTarget: defaultTarget,
      choice: choice,
    ),
    service: service,
    lyrics: lyrics,
    rows: rows,
    knownPlugins: plugins.known,
    livePlugins: plugins.live,
    job: null,
  );
  return (key: key, target: target, needsRequest: derived.needsRequest);
}

/// The lyrics the song at [path] would show, read without playing it and
/// without an online lookup. Null when it has none, the read failed, or [stop]
/// completed first. The subscription is closed before returning.
Future<Lyrics?> previewLyricsOf(Ref ref, String path, Future<void> stop) async {
  final done = Completer<Lyrics?>();
  final sub = ref.listen(trackLyricsPreviewProvider(path), (_, value) {
    if (value.isLoading || done.isCompleted) return;
    done.complete(value.hasError ? null : value.value?.lyrics);
  }, fireImmediately: true);
  try {
    return await Future.any([done.future, stop.then((_) => null)]);
  } finally {
    sub.close();
  }
}
