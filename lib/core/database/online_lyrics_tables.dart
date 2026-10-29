import 'package:drift/drift.dart';

// Online lyrics: lookup results, per-song picks and rejected matches. Times
// are epoch milliseconds, like the rest of the library database.
//
// Invariants (the contract for every writer and reader):
// 1. `cache_key` is a hash of the song's metadata (artist, title, album,
//    duration; see `core/lyrics_online`), `track_key` is the local path, else
//    the uri. No foreign key to `tracks`: rows are keyed by value, so moved,
//    renamed and duplicate files share them.
// 2. Rows survive rescans and "reset library" (same rule as user data
//    invariant 7 in `user_data_tables.dart`).
// 3. A `found` row never expires. A `not_found` row older than the miss TTL
//    counts as a miss and the next lookup overwrites it.
// 4. A rejected (cache_key, provider_id, remote_id) is never stored as found
//    for that key again, and neither is a record whose text hash equals a
//    rejected `content_hash`; lookups drop rejected ids and hashes before
//    ranking. A reject made before hashes existed has a null hash and
//    matches by id only.
// 5. `status` holds only `found` or `not_found` and `provider_id` only ids of
//    known providers; there is no CHECK constraint, readers skip unknown
//    values so a newer build's rows do not break an older one.
// 6. `remote_id` is null exactly when `status` is `not_found`. In
//    `lyrics_pins`, `mode` is the song's lyrics choice: `local`, `online` or
//    `off`. Null or an unknown value (from a newer build) reads as auto and
//    the row is kept. `online` implies a pick is present. A null `remote_id`
//    means no pick is stored. A pin carries its own text and never reads
//    `online_lyrics`.
// 7. "Clear online lyrics" empties all three tables. It never touches `.lrc`
//    files.
// 8. Resolving which lyrics to show never writes; only user actions and
//    lookups do.
// 9. Unbounded by design (a few KB per song); settings shows count and size.

/// One lookup result for one metadata key from one provider.
@DataClassName('OnlineLyricsRow')
class OnlineLyrics extends Table {
  TextColumn get cacheKey => text()();

  TextColumn get providerId => text()();

  /// 'found' or 'not_found'.
  TextColumn get status => text()();

  /// The provider's id for the match; null when not found.
  TextColumn get remoteId => text().nullable()();

  TextColumn get syncedText => text().nullable()();

  TextColumn get plainText => text().nullable()();

  BoolColumn get instrumental => boolean().withDefault(const Constant(false))();

  /// The duration the provider reports for the match.
  IntColumn get remoteDurationMs => integer().nullable()();

  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {cacheKey, providerId};
}

/// The lyrics choice and the online pick of one song.
@DataClassName('LyricsPinRow')
class LyricsPins extends Table {
  TextColumn get trackKey => text()();

  TextColumn get providerId => text().nullable()();

  /// The lyrics choice: `local`, `online` or `off`; null = auto.
  TextColumn get mode => text().nullable()();

  /// Null = no pick stored.
  TextColumn get remoteId => text().nullable()();

  TextColumn get syncedText => text().nullable()();

  TextColumn get plainText => text().nullable()();

  BoolColumn get instrumental => boolean().withDefault(const Constant(false))();

  IntColumn get remoteDurationMs => integer().nullable()();

  IntColumn get pinnedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackKey};
}

/// A match the user marked "Not these lyrics" for one metadata key.
@DataClassName('OnlineLyricsRejectRow')
class OnlineLyricsRejects extends Table {
  TextColumn get cacheKey => text()();

  TextColumn get providerId => text()();

  TextColumn get remoteId => text()();

  /// `lyricsContentHash` of the rejected text; null for older rejects.
  TextColumn get contentHash => text().nullable()();

  IntColumn get rejectedAt => integer()();

  @override
  Set<Column> get primaryKey => {cacheKey, providerId, remoteId};
}
