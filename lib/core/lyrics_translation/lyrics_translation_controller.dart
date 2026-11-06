import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/lyrics.dart';
import '../lyrics/online/lyrics_target.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/playing_track_lyrics_provider.dart';
import '../player/player_service.dart';
import '../settings/settings_provider.dart';
import 'lyrics_content_hash.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translation_state.dart';
import 'translation_jobs.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_providers.dart';
import 'translation_service.dart';
import 'translation_service_resolution.dart';
import 'translation_song_context.dart';

/// How long the same lyrics stay on screen before a request is made, so
/// skipping through songs does not translate each one. Tests shorten it.
final translationDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

final _hashes = Expando<String>();

String _hashOf(Lyrics lyrics) => _hashes[lyrics] ??= lyricsContentHash(lyrics);

/// The translation state of the playing lyrics. Only a Now Playing widget
/// that watches it makes requests; closing Now Playing disposes it (and its
/// debounce timer), while a job already started finishes and saves. The
/// argument is the app's language code, the default target; `core` does not
/// read the app's localizations itself.
class LyricsTranslationController extends Notifier<LyricsTranslationState> {
  LyricsTranslationController(this.appLang);

  final String appLang;

  // What the last build looked at; the methods act on it.
  TranslationJobKey? _key;
  Lyrics? _lyrics;
  TranslationLanguage? _target;
  TranslationTargetInfo? _info;

  @override
  LyricsTranslationState build() {
    _key = _lyrics = _target = _info = null;
    // Nothing is wanted until a full path below says so; a chunk of the
    // previous song still waiting for its turn is then dropped unsent.
    ref.read(translationJobsProvider.notifier).setCurrent(null);
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    final playing = ref.watch(playingTrackLyricsProvider).value;
    final db = ref.watch(libraryDatabaseProvider);
    if (db == null || playing == null || playing.uri != uri) {
      return const TranslationUnavailable();
    }
    final lyrics = playing.lyrics;
    final hash = _hashOf(lyrics);
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final chosen = ref.watch(effectiveTranslationServiceProvider);
    final defaultTarget =
        translationLanguageFor(prefs.targetLanguage ?? appLang) ??
        translationLanguageFor('en')!;
    final songTarget = ref.watch(songTranslationTargetProvider(hash));
    final targetKnown = songTarget.hasValue || songTarget.hasError;
    final override = songTarget.hasError ? null : songTarget.value;
    final effective =
        (override == null ? null : translationLanguageFor(override)) ??
        defaultTarget;
    final info = TranslationTargetInfo(
      hash: hash,
      effective: targetKnown ? effective : defaultTarget,
      songOverride: override,
      defaultTarget: defaultTarget,
    );
    _info = info;

    final stored = prefs.service;
    if (!prefs.show || stored == null) return TranslationOff(info);
    if (chosen == null) {
      final records = ref.watch(translatePluginRecordsProvider);
      if (records.hasError) return const TranslationUnavailable();
      if (!records.hasValue) return TranslationLoading(info, stored);
      return TranslationOff(info);
    }
    final service = chosen;
    if (needsNoticeFor(prefs, service)) {
      return TranslationNeedsNotice(info, service);
    }
    if (!targetKnown) return TranslationLoading(info, service);
    final key = TranslationJobKey(hash, info.effective.code, service);

    final rows = ref.watch(
      cachedTranslationsProvider((hash, info.effective.code)),
    );
    if (rows.hasError) return const TranslationUnavailable();
    // From here on a request is possible, so the actions may act.
    _key = key;
    ref.read(translationJobsProvider.notifier).setCurrent(key);
    _lyrics = lyrics;
    _target = info.effective;
    if (!rows.hasValue) return TranslationLoading(info, service);
    final job = ref.watch(translationJobsProvider.select((m) => m[key]));

    final derived = deriveTranslation(
      info: info,
      service: service,
      lyrics: lyrics,
      rows: rows.requireValue,
      knownPlugins: {
        for (final r in ref.watch(lyricsPluginRecordsProvider))
          if (r.kind?.isTranslation == true)
            ?TranslationServiceId.tryParse(r.installId),
      },
      job: job,
    );
    if (derived.needsRequest) _armRequest(key, lyrics, info.effective);
    return derived.state;
  }

  /// Requests the translation if the state is still "needs a request" after
  /// the debounce; `run` dedupes, so a re-armed timer is harmless. Only this
  /// timer is tied to the rebuild: a job must not be.
  void _armRequest(
    TranslationJobKey key,
    Lyrics lyrics,
    TranslationLanguage target,
  ) {
    final jobs = ref.read(translationJobsProvider.notifier);
    final timer = Timer(
      ref.read(translationDebounceProvider),
      () => unawaited(
        jobs.run(key, uniqueLineTexts(lyrics), target, song: _songContext()),
      ),
    );
    ref.onDispose(timer.cancel);
  }

  /// Translates again with the selected service, replacing its saved row; the
  /// version on screen stays until the new one is saved. Returns how the job
  /// ended (`saved`, `failed`), or null when it did not run or was cancelled.
  Future<TranslationJobStatus?> retranslate() async {
    final (key, lyrics, target) = (_key, _lyrics, _target);
    if (key == null || lyrics == null || target == null) return null;
    final jobs = ref.read(translationJobsProvider.notifier);
    return jobs.run(
      key,
      uniqueLineTexts(lyrics),
      target,
      force: true,
      song: _songContext(),
    );
  }

  /// Stops a retranslate that is running; the older version shows again.
  void cancelRetranslate() {
    final key = _key;
    if (key != null) ref.read(translationJobsProvider.notifier).cancel(key);
  }

  /// Hides the failure of a retranslate and keeps the version on screen.
  void dismissRetranslateFailure() {
    final key = _key;
    if (key != null) {
      ref.read(translationJobsProvider.notifier).clearFailure(key);
    }
  }

  /// Forgets the remembered failure and tries again; chunks translated before
  /// the failure are not sent twice.
  Future<void> retry() async {
    final (key, lyrics, target) = (_key, _lyrics, _target);
    if (key == null || lyrics == null || target == null) return;
    final jobs = ref.read(translationJobsProvider.notifier)..clearFailure(key);
    await jobs.run(key, uniqueLineTexts(lyrics), target, song: _songContext());
  }

  /// Title and artist of the playing track, read when a request is made. A
  /// title that is only the file name is dropped, as for the lyrics lookup.
  TranslationSongContext? _songContext() {
    final track = ref.read(playerServiceProvider).queue.current;
    if (track == null) return null;
    final query = LyricsTarget.fromTrack(track).query;
    return TranslationSongContext(title: query.title, artist: query.artist);
  }

  /// Sets the language for this song only; null goes back to the default.
  Future<void> setSongTarget(String? code) async {
    final hash = _info?.hash;
    final db = ref.read(libraryDatabaseProvider);
    if (hash == null || db == null) return;
    await db.setSongTranslationTarget(hash, code);
  }
}

/// [appLang] is `Localizations.localeOf(context).languageCode`.
final lyricsTranslationProvider = NotifierProvider.autoDispose
    .family<LyricsTranslationController, LyricsTranslationState, String>(
      LyricsTranslationController.new,
      retry: (_, _) => null,
    );
