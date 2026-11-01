import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_favorites.dart';
import 'playlist_write_helpers.dart';
import 'playlist_writes.dart';

/// What to do with paths a target playlist already holds.
enum PlaylistAddMode {
  /// Append every path as given, repeats inside the batch kept.
  appendAll,

  /// Same as `addMissingToPlaylist`: the batch is deduped (first occurrence
  /// wins) and paths the playlist already holds are dropped.
  missingOnly,

  /// Delete the target's entries whose path is in the batch, close the gaps,
  /// then append every path as given.
  replaceOld,
}

/// Totals of one [PlaylistAddWrites.addToPlaylists] call.
class PlaylistAddOutcome {
  const PlaylistAddOutcome({
    this.added = 0,
    this.skipped = 0,
    this.removed = 0,
    this.created = const [],
    this.gone = 0,
    this.targetCount = 0,
  });

  /// Entries written, over all targets and new playlists.
  final int added;

  /// Distinct paths left out by [PlaylistAddMode.missingOnly], summed.
  final int skipped;

  /// Old copies deleted by [PlaylistAddMode.replaceOld], summed.
  final int removed;

  /// Trimmed names of the new playlists, in order.
  final List<String> created;

  /// Targets that no longer existed and were skipped.
  final int gone;

  /// Existing playlists written plus new playlists created.
  final int targetCount;
}

extension PlaylistAddWrites on LibraryDatabase {
  /// Adds [paths] to every playlist of [targets] (each with its own mode) and
  /// to new playlists named [newNames], all in one transaction. [now] is epoch
  /// milliseconds.
  ///
  /// New playlists get every path as given. Favorites is always handled as
  /// [PlaylistAddMode.missingOnly], whatever its mode says. A target that is
  /// gone is skipped and counted in `gone`. A blank name throws
  /// [ArgumentError] before anything is written. Empty [paths] writes nothing.
  Future<PlaylistAddOutcome> addToPlaylists({
    required List<String> paths,
    Map<int, PlaylistAddMode> targets = const {},
    List<String> newNames = const [],
    required int now,
  }) async {
    final names = [for (final name in newNames) validPlaylistName(name)];
    if (paths.isEmpty) return const PlaylistAddOutcome();
    return transaction(() async {
      var added = 0, skipped = 0, removed = 0, gone = 0, written = 0;
      for (final name in names) {
        await createPlaylist(name, now: now, paths: paths);
        added += paths.length;
        written++;
      }
      final kinds = await _kindsOf(targets.keys);
      for (final MapEntry(key: id, value: mode) in targets.entries) {
        if (!kinds.containsKey(id)) {
          gone++;
          continue;
        }
        written++;
        if (kinds[id] == favoritesKind || mode == PlaylistAddMode.missingOnly) {
          final result = await addMissingToPlaylist(id, paths);
          added += result.added;
          skipped += result.skipped;
          continue;
        }
        if (mode == PlaylistAddMode.replaceOld) {
          final n = await _deleteHeld(id, paths);
          removed += n;
          if (n > 0) await renumberPlaylist(id);
        }
        await appendPlaylistPaths(
          id,
          paths,
          start: await playlistEntryCount(id),
        );
        added += paths.length;
      }
      return PlaylistAddOutcome(
        added: added,
        skipped: skipped,
        removed: removed,
        created: List.unmodifiable(names),
        gone: gone,
        targetCount: written,
      );
    });
  }

  /// Kind of each existing playlist among [ids] (null for ordinary ones);
  /// ids that are gone are absent.
  Future<Map<int, String?>> _kindsOf(Iterable<int> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (select(playlists)..where((p) => p.id.isIn(ids))).get();
    return {for (final row in rows) row.id: row.kind};
  }

  /// Deletes the entries of playlist [id] whose path is in [paths] and
  /// returns how many went. The caller renumbers.
  Future<int> _deleteHeld(int id, List<String> paths) => customUpdate(
    'DELETE FROM playlist_entries WHERE playlist_id = ?1 '
    'AND path IN (SELECT value FROM json_each(?2))',
    variables: [
      Variable.withInt(id),
      Variable.withString(jsonEncode(paths.toSet().toList())),
    ],
    updates: {playlistEntries},
    updateKind: UpdateKind.delete,
  );
}
