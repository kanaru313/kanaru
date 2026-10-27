import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import 'google_translator.dart';
import 'lyrics_translator.dart';
import 'translation_cache.dart';

/// The one HTTP client of every translation request. Tests override it.
final translationHttpClientProvider = Provider<HttpClient>((ref) {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'Kanaru';
  ref.onDispose(() => client.close(force: true));
  return client;
});

final googleTranslatorProvider = Provider<LyricsTranslator>(
  (ref) => GoogleTranslator(ref.watch(translationHttpClientProvider)),
);

/// The language picked for the lyrics text [hash] only, or `null`. Emits
/// `null` when the library database is unavailable.
final songTranslationTargetProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, hash) {
      final db = ref.watch(libraryDatabaseProvider);
      return db == null
          ? Stream<String?>.value(null)
          : db.watchSongTranslationTarget(hash);
    }, retry: (_, _) => null);

/// Cached translations of (lyrics hash, target language code) by any
/// service, unreadable rows left out.
final cachedTranslationsProvider = StreamProvider.autoDispose
    .family<List<CachedTranslation>, (String, String)>((ref, arg) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const <CachedTranslation>[]);
      return db
          .watchLyricTranslations(arg.$1, arg.$2)
          .map((rows) => [for (final row in rows) ?decodeTranslationRow(row)]);
    }, retry: (_, _) => null);

/// Number and size of the saved translations, for the settings screen.
final translationCacheStatsProvider =
    StreamProvider.autoDispose<({int count, int bytes})>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      return db == null
          ? Stream.value((count: 0, bytes: 0))
          : db.watchLyricTranslationStats();
    }, retry: (_, _) => null);
