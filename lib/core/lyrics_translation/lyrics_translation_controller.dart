import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/lyrics.dart';
import '../lyrics/playing_track_lyrics_provider.dart';
import '../player/player_service.dart';
import '../settings/settings_provider.dart';
import 'deepl_key_provider.dart';
import 'lyrics_content_hash.dart';
import 'lyrics_translation_derive.dart';
import 'lyrics_translation_state.dart';
import 'translation_failure.dart';
import 'translation_jobs.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_providers.dart';
import 'translation_service.dart';

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
    final service = prefs.service;
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

    if (!prefs.show) return TranslationOff(info);
    if (prefs.needsNotice) return TranslationNeedsNotice(info, service);
    if (!targetKnown) return TranslationLoading(info, service);
    final key = TranslationJobKey(hash, info.effective.code, service);

    final rows = ref.watch(
      cachedTranslationsProvider((hash, info.effective.code)),
    );
    if (rows.hasError) return const TranslationUnavailable();
    // From here on a request is possible, so the actions may act.
    _key = key;
    _lyrics = lyrics;
    _target = info.effective;
    if (!rows.hasValue) return TranslationLoading(info, service);
    final deeplKey = service == LyricsTranslationService.deepl
        ? ref.watch(deeplApiKeyProvider)
        : null;
    final job = ref.watch(translationJobsProvider.select((m) => m[key]));

    final derived = deriveTranslation(
      info: info,
      service: service,
      lyrics: lyrics,
      rows: rows.requireValue,
      job: job,
      deeplKey: deeplKey,
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
      () => unawaited(jobs.run(key, uniqueLineTexts(lyrics), target)),
    );
    ref.onDispose(timer.cancel);
  }

  /// Translates again with the selected service, replacing its saved row.
  Future<void> retranslate() async {
    final (key, lyrics, target) = (_key, _lyrics, _target);
    if (key == null || lyrics == null || target == null) return;
    await ref
        .read(translationJobsProvider.notifier)
        .run(key, uniqueLineTexts(lyrics), target, force: true);
  }

  /// Forgets the remembered failure and tries again; chunks translated before
  /// the failure are not sent twice.
  Future<void> retry() async {
    final (key, lyrics, target) = (_key, _lyrics, _target);
    if (key == null || lyrics == null || target == null) return;
    final failed = state;
    final keyStoreFailed =
        failed is TranslationFailed &&
        (failed.kind == TranslationFailureKind.keyStoreLocked ||
            failed.kind == TranslationFailureKind.keyStoreUnavailable);
    // A locked keyring may be unlocked by now: read the key again.
    if (key.service == LyricsTranslationService.deepl &&
        (keyStoreFailed || ref.read(deeplApiKeyProvider).hasError)) {
      ref.invalidate(deeplApiKeyProvider);
    }
    final jobs = ref.read(translationJobsProvider.notifier)..clearFailure(key);
    await jobs.run(key, uniqueLineTexts(lyrics), target);
  }

  /// Switches to the other service. Returns true when it was switched. When
  /// the other service's notice was not accepted yet, nothing changes and
  /// this returns false: the caller shows the notice and, after Continue,
  /// calls `SettingsNotifier.enableTranslation` with that service.
  bool useOtherService() {
    final prefs = ref.read(settingsProvider).translation;
    final other = prefs.service.other;
    if (!prefs.noticeAcknowledged.contains(other)) return false;
    ref
        .read(settingsProvider.notifier)
        .setTranslation(prefs.copyWith(service: other));
    return true;
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
