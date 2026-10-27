import 'package:drift/drift.dart';

// Cached lyrics translations. Times are epoch milliseconds, like the rest of
// the library database.
//
// Invariants (the contract for every writer and reader):
// 1. `content_hash` is `lyricsContentHash`
//    (`core/lyrics_translation/lyrics_content_hash.dart`) and the only key.
//    No foreign key to `tracks`: moved, renamed and duplicate files share
//    rows; edited lyrics text orphans the old row.
// 2. Rows survive rescans and "reset library" (same rule as user data
//    invariant 7 in `user_data_tables.dart`). Orphans stay until "Clear saved
//    translations".
// 3. `lines_json` is a JSON object, source text to translation. Lines
//    without a usable translation are absent. A row is written only when the
//    map is non-empty or the song is judged same-language (`source_lang`
//    base equals the target). A same-language row keeps whatever lines did
//    differ (already paid for, e.g. an English chorus in a Vietnamese song),
//    but the UI shows only a note. An empty map with a different source is
//    never stored: that is a failed translation, not a result.
// 4. Retranslating replaces only its own provider's row
//    (`INSERT ... ON CONFLICT DO UPDATE` on the primary key).
// 5. `provider` holds only `google` or `deepl`; readers skip unknown values.
// 6. `lyric_translation_prefs` is a user choice: clearing translations does
//    not touch it.
// 7. Unbounded by design (a few KB per song); settings shows count and size.

/// One translation of one lyrics text by one service into one language.
@DataClassName('LyricTranslationRow')
class LyricTranslations extends Table {
  TextColumn get contentHash => text()();

  /// 'google' or 'deepl'.
  TextColumn get provider => text()();

  /// Internal language code, for example 'vi' or 'zh-Hans'.
  TextColumn get targetLang => text()();

  /// Dominant detected base language code, when known.
  TextColumn get sourceLang => text().nullable()();

  /// `{"source line": "translation"}`.
  TextColumn get linesJson => text()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {contentHash, provider, targetLang};
}

/// The target language the user picked for one lyrics text.
@DataClassName('LyricTranslationPrefRow')
class LyricTranslationPrefs extends Table {
  TextColumn get contentHash => text()();

  TextColumn get targetLang => text()();

  @override
  Set<Column> get primaryKey => {contentHash};
}
