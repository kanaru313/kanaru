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
// 5. `provider` holds a translate plugin install id (`plugin-...`); readers
//    skip unknown values, retired built-in service rows (`deepl`, etc.)
//    included.
// 6. `lyric_translation_prefs` is a user choice: clearing translations does
//    not touch it. It holds a target language, a per-song instruction for AI
//    plugins, or both; a row with both null is deleted.
// 7. Unbounded by design (a few KB per song); settings shows count and size.
// 8. `settings_json` is the snapshot of the AI settings a row was made with
//    (`{"model", "style", "instructionHash"}`); null for plugins without AI
//    settings and for rows made before the column existed. A save always
//    writes it, null included, so a retranslate never keeps an older snapshot.

/// One translation of one lyrics text by one service into one language.
@DataClassName('LyricTranslationRow')
class LyricTranslations extends Table {
  TextColumn get contentHash => text()();

  /// A plugin install id; readers skip unknown values, retired built-in rows
  /// (`deepl`, etc.) included.
  TextColumn get provider => text()();

  /// Internal language code, for example 'vi' or 'zh-Hans'.
  TextColumn get targetLang => text()();

  /// Dominant detected base language code, when known.
  TextColumn get sourceLang => text().nullable()();

  /// `{"source line": "translation"}`.
  TextColumn get linesJson => text()();

  /// Snapshot of the AI settings of the run; see invariant 8.
  TextColumn get settingsJson => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {contentHash, provider, targetLang};
}

/// What the user picked for one lyrics text: a target language, an
/// instruction for AI plugins, or both (null = no choice).
@DataClassName('LyricTranslationPrefRow')
class LyricTranslationPrefs extends Table {
  TextColumn get contentHash => text()();

  TextColumn get targetLang => text().nullable()();

  /// Free text appended to the plugin's own instruction for this song.
  TextColumn get instruction => text().nullable()();

  @override
  Set<Column> get primaryKey => {contentHash};
}
