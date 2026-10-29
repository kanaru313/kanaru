import 'package:drift/drift.dart';

import 'library_database.dart';

/// Writes and lookups for the per-song lyrics choice, picks and rejects; see
/// the invariants in `online_lyrics_tables.dart`. `mode` travels as the raw
/// stored string so the database layer knows no lyrics types.
extension LyricsChoiceQueries on LibraryDatabase {
  /// Replaces the whole pin of the song (choice and pick); columns the new
  /// row leaves out are reset, not kept.
  Future<void> pinLyrics(LyricsPinsCompanion row) =>
      into(lyricsPins).insert(row, mode: InsertMode.insertOrReplace);

  /// Sets the song's choice and leaves any stored pick untouched. Callers
  /// never pass `online` without a stored pick: `online` implies a pick.
  Future<void> setLyricsChoice(String trackKey, String mode, int now) {
    return customInsert(
      'INSERT INTO lyrics_pins (track_key, mode, pinned_at) '
      'VALUES (?1, ?2, ?3) '
      'ON CONFLICT(track_key) DO UPDATE SET '
      'mode = excluded.mode, pinned_at = excluded.pinned_at',
      variables: [
        Variable<String>(trackKey),
        Variable<String>(mode),
        Variable<int>(now),
      ],
      updates: {lyricsPins},
    );
  }

  /// Back to automatic: forgets the choice and the pick.
  Future<void> removeLyricsPin(String trackKey) =>
      (delete(lyricsPins)..where((t) => t.trackKey.equals(trackKey))).go();

  /// A pick, in one transaction: stores [row] with `mode = 'online'` and
  /// forgets the rejects of [cacheKey] that flag the same record, by id or,
  /// when [contentHash] is given, by text. Picking a rejected record undoes
  /// the reject. Also the write path for keeping the shown lyrics.
  Future<void> pickOnlineLyrics(
    LyricsPinsCompanion row, {
    required String cacheKey,
    required String providerId,
    required String remoteId,
    String? contentHash,
  }) {
    return transaction(() async {
      await pinLyrics(row.copyWith(mode: const Value('online')));
      await (delete(onlineLyricsRejects)..where((t) {
            final sameRecord =
                t.providerId.equals(providerId) & t.remoteId.equals(remoteId);
            return t.cacheKey.equals(cacheKey) &
                (contentHash == null
                    ? sameRecord
                    : sameRecord | t.contentHash.equals(contentHash));
          }))
          .go();
    });
  }

  /// "Not these lyrics", in one transaction: remembers the rejected match
  /// (and its text hash) for [cacheKey], deletes the found rows of that key
  /// holding [remoteId] or any of [duplicateRemoteIds], and clears the pick
  /// of [trackKey] when it is that record. A pin left with no pick and a
  /// `online` or empty mode is deleted. Writes no skip: the song goes back to
  /// automatic resolution unless its choice is `local` or `off`.
  Future<void> rejectOnlineLyrics({
    required String cacheKey,
    required String providerId,
    required String remoteId,
    String? contentHash,
    Set<String> duplicateRemoteIds = const {},
    required String trackKey,
    required int now,
  }) {
    return transaction(() async {
      await into(onlineLyricsRejects).insertOnConflictUpdate(
        OnlineLyricsRejectsCompanion.insert(
          cacheKey: cacheKey,
          providerId: providerId,
          remoteId: remoteId,
          contentHash: Value(contentHash),
          rejectedAt: now,
        ),
      );
      final gone = {remoteId, ...duplicateRemoteIds};
      await (delete(onlineLyrics)
            ..where((t) => t.cacheKey.equals(cacheKey) & t.remoteId.isIn(gone)))
          .go();
      final pin = await (select(
        lyricsPins,
      )..where((t) => t.trackKey.equals(trackKey))).getSingleOrNull();
      if (pin == null ||
          pin.providerId != providerId ||
          pin.remoteId != remoteId) {
        return;
      }
      if (pin.mode == null || pin.mode == 'online') {
        await removeLyricsPin(trackKey);
      } else {
        await (update(
          lyricsPins,
        )..where((t) => t.trackKey.equals(trackKey))).write(
          const LyricsPinsCompanion(
            providerId: Value(null),
            remoteId: Value(null),
            syncedText: Value(null),
            plainText: Value(null),
            instrumental: Value(false),
            remoteDurationMs: Value(null),
          ),
        );
      }
    });
  }

  /// The rejected matches for one metadata key: (provider id, remote id)
  /// pairs and the non-null text hashes.
  Future<({Set<(String, String)> ids, Set<String> hashes})> rejectedMatches(
    String cacheKey,
  ) async {
    final rows = await (select(
      onlineLyricsRejects,
    )..where((t) => t.cacheKey.equals(cacheKey))).get();
    return (
      ids: {for (final r in rows) (r.providerId, r.remoteId)},
      hashes: {
        for (final r in rows)
          if (r.contentHash != null) r.contentHash!,
      },
    );
  }

  /// The stored text of one record: the song's pin when its ids match, else
  /// the found cache row of [cacheKey] with that [remoteId], else null.
  Future<
    ({String? synced, String? plain, bool instrumental, int? remoteDurationMs})?
  >
  storedOnlineLyricsText({
    required String trackKey,
    required String cacheKey,
    required String providerId,
    required String remoteId,
  }) async {
    final pin = await (select(
      lyricsPins,
    )..where((t) => t.trackKey.equals(trackKey))).getSingleOrNull();
    if (pin != null &&
        pin.providerId == providerId &&
        pin.remoteId == remoteId) {
      return (
        synced: pin.syncedText,
        plain: pin.plainText,
        instrumental: pin.instrumental,
        remoteDurationMs: pin.remoteDurationMs,
      );
    }
    final row =
        await (select(onlineLyrics)..where(
              (t) =>
                  t.cacheKey.equals(cacheKey) &
                  t.providerId.equals(providerId) &
                  t.remoteId.equals(remoteId) &
                  t.status.equals('found'),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return (
      synced: row.syncedText,
      plain: row.plainText,
      instrumental: row.instrumental,
      remoteDurationMs: row.remoteDurationMs,
    );
  }
}
