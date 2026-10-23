import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_page_queries.dart';
import '../../core/database/playlist_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/database/throttled_tracks_query.dart';
import '../../shared/library_browse_refresh.dart';

/// Runs [load] at once on playlist edits and at most every
/// `libraryBrowseRefreshIntervalProvider` while `tracks` changes.
///
/// An edit invalidates the provider, which starts a fresh stream whose first
/// load is immediate; a scan only marks the running stream dirty, so a scan
/// cannot keep the database busy with reloads (see `throttledTracksQuery`).
/// Every load builds new objects: the page view tells new data from a reload
/// state by identity.
Stream<T> _playlistQuery<T>(
  Ref ref,
  LibraryDatabase db,
  Future<T> Function() load,
) {
  final edits = db
      .tableUpdates(
        TableUpdateQuery.onAllTables([db.playlists, db.playlistEntries]),
      )
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(edits.cancel);
  return throttledTracksQuery(
    db,
    load,
    interval: ref.watch(libraryBrowseRefreshIntervalProvider),
  );
}

/// A head as one load produced it. [seq] is taken when the load starts, from
/// a counter that only grows, so of two loads the one that started later has
/// the higher number. A page view that has just saved an edit asks for
/// [nextPlaylistHeadSeq] and ignores heads below it: they may have been read
/// before the edit and still show the old count.
class PlaylistHeadLoad {
  const PlaylistHeadLoad({required this.seq, required this.head});

  final int seq;

  /// Null when the playlist does not exist.
  final PlaylistPageHead? head;
}

var _lastHeadSeq = 0;

/// The lowest [PlaylistHeadLoad.seq] a load that starts from now on gets.
int nextPlaylistHeadSeq() => _lastHeadSeq + 1;

/// The header data of one playlist (summary, collage, whether anything can
/// play); `head` is null when it does not exist (or without a library). The
/// entries are read by the page view, a window at a time.
final playlistPageHeadProvider = StreamProvider.autoDispose
    .family<PlaylistHeadLoad, int>((ref, id) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) {
        return Stream.value(PlaylistHeadLoad(seq: ++_lastHeadSeq, head: null));
      }
      return _playlistQuery(ref, db, () async {
        final seq = ++_lastHeadSeq;
        return PlaylistHeadLoad(seq: seq, head: await db.playlistPageHead(id));
      });
    });

/// Every playlist with its collage keys, newest first.
final playlistCardsProvider = StreamProvider.autoDispose<List<PlaylistCard>>((
  ref,
) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return _playlistQuery(ref, db, db.playlistCards);
});
