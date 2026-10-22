import 'package:drift/drift.dart';

// User data that a library scan cannot rebuild: listen history and playlists.
// Times are epoch milliseconds, like the rest of the library database.
//
// Invariants (the contract for every writer and reader):
// 1. Path spelling. `path` is the canonical spelling the indexer stores in
//    `tracks.path`: absolute, under a symlink-resolved root, bytes as on disk
//    (no Unicode normalization). Writers starting from a track row copy
//    `tracks.path`; other sources (player `file://` URIs, M3U import,
//    restored sessions) must resolve the parent directory's symlinks and
//    normalize `.`/`..` before writing.
// 2. No foreign key to `tracks`. Removing a root, rescanning and replacing a
//    root delete track rows; `plays`, `play_stats` and `playlist_entries`
//    survive and match again by path when a file with the same path returns.
//    A moved file or replaced folder orphans its rows until a re-link exists.
// 3. Plays are log rows. `path` and `played_at` are not changed in normal
//    use; only the recorder updates `listened_ms` of the play it is
//    recording. Rows are otherwise inserted or deleted.
// 4. Stats are stored and kept by triggers (`listen_history.drift`). Never
//    write `play_stats` from Dart, including clear-all (`DELETE FROM plays`
//    alone is enough). Write `plays` through drift APIs or
//    `customUpdate(updates: {plays})`, never a bare `customStatement`, so
//    watchers of `play_stats` re-run.
// 5. Dense positions. Writers keep `position` = 0..n-1 per playlist and
//    change positions only inside one transaction. Readers order by
//    `position, id`.
// 6. The playlist cover is computed (first entries by position), not stored.
// 7. This data lives in `library.db`: a "reset library" must delete roots and
//    tracks, never the file.

/// One listen of a track. Append-mostly log; see invariants 1-4 above.
@DataClassName('Play')
@TableIndex(name: 'plays_path_played', columns: {#path, #playedAt})
// Covering index for date-range aggregates grouped by path.
@TableIndex(name: 'plays_played_at', columns: {#playedAt, #path})
class Plays extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Canonical `tracks.path` spelling; deliberately no foreign key.
  TextColumn get path => text()();

  /// When playback of this play started.
  IntColumn get playedAt => integer()();

  /// Accumulated listening time; null when unknown (for example an import).
  IntColumn get listenedMs => integer().nullable()();
}

/// Per-track play count and first/last play time.
///
/// Written only by the triggers in `listen_history.drift`; never write it
/// from Dart. A row exists exactly while the track has at least one play.
@DataClassName('PlayStat')
class PlayStats extends Table {
  TextColumn get path => text()();
  IntColumn get playCount => integer()();
  IntColumn get firstPlayedAt => integer()();
  IntColumn get lastPlayedAt => integer()();

  @override
  Set<Column> get primaryKey => {path};
}

/// A user playlist. Names are not unique.
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
}

/// One entry of a playlist. The same path may appear several times; the row
/// `id` is the entry identity. See invariants 1, 2 and 5 above.
@DataClassName('PlaylistEntry')
@TableIndex(name: 'playlist_entries_order', columns: {#playlistId, #position})
class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// Canonical `tracks.path` spelling; deliberately no foreign key.
  TextColumn get path => text()();

  /// Dense 0..n-1 per playlist; not unique.
  IntColumn get position => integer()();
}
