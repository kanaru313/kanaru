import 'package:drift/drift.dart';

import 'library_database.dart';

/// Playlist writes. Each one is a single transaction, so positions stay
/// `0..n-1` and watchers see the final state only.
extension PlaylistWrites on LibraryDatabase {
  /// Creates a playlist named [name] (trimmed) holding [paths] in order and
  /// returns its id. [now] is epoch milliseconds. An empty name throws
  /// [ArgumentError].
  Future<int> createPlaylist(
    String name, {
    required int now,
    List<String> paths = const [],
  }) async {
    final trimmed = _validName(name);
    return await transaction(() async {
      final id = await into(playlists)
          .insert(PlaylistsCompanion.insert(name: trimmed, createdAt: now));
      await _append(id, paths, start: 0);
      return id;
    });
  }

  /// Renames playlist [id]; does nothing when it is gone. An empty name
  /// throws [ArgumentError].
  Future<void> renamePlaylist(int id, String name) async {
    final trimmed = _validName(name);
    await (update(playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(name: Value(trimmed)),
    );
  }

  /// Deletes playlist [id]; its entries go with it (cascade).
  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((p) => p.id.equals(id))).go();

  /// Appends [paths] in order and returns how many were added. Throws, and
  /// adds nothing, when the playlist is gone. Repeated paths are stored as
  /// given: skipping duplicates is the caller's job (`playlistPathsAmong`).
  Future<int> addToPlaylist(int id, List<String> paths) {
    if (paths.isEmpty) return Future.value(0);
    return transaction(() async {
      final count = playlistEntries.id.count();
      final row =
          await (selectOnly(playlistEntries)
                ..addColumns([count])
                ..where(playlistEntries.playlistId.equals(id)))
              .getSingle();
      await _append(id, paths, start: row.read(count) ?? 0);
      return paths.length;
    });
  }

  /// The subset of [paths] that playlist [id] already holds.
  Future<Set<String>> playlistPathsAmong(int id, Iterable<String> paths) async {
    final wanted = paths.toSet();
    if (wanted.isEmpty) return {};
    final rows =
        await (selectOnly(playlistEntries, distinct: true)
              ..addColumns([playlistEntries.path])
              ..where(playlistEntries.playlistId.equals(id)))
            .get();
    return {for (final row in rows) ?row.read(playlistEntries.path)}
        .intersection(wanted);
  }

  /// Deletes the entries [entryIds] of playlist [id] and closes the gaps.
  /// Ids that belong to another playlist are ignored.
  Future<void> removePlaylistEntries(int id, Set<int> entryIds) {
    if (entryIds.isEmpty) return Future.value();
    return transaction(() async {
      await (delete(
        playlistEntries,
      )..where((e) => e.playlistId.equals(id) & e.id.isIn(entryIds))).go();
      await customUpdate(
        '''
UPDATE playlist_entries AS e SET position = r.rn
FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) - 1 AS rn
      FROM playlist_entries WHERE playlist_id = ?1) AS r
WHERE e.id = r.id AND e.position != r.rn''',
        variables: [Variable.withInt(id)],
        updates: {playlistEntries},
        updateKind: UpdateKind.update,
      );
    });
  }

  /// Moves entry [entryId] of playlist [id] so it ends up at index [to] of
  /// the list, as `list.insert(to, list.removeAt(from))` would; [to] is
  /// clamped to the list. Throws [StateError], and changes nothing, when the
  /// entry is not in this playlist.
  Future<void> movePlaylistEntry(int id, int entryId, int to) {
    return transaction(() async {
      final entry =
          await (select(playlistEntries)
                ..where((e) => e.id.equals(entryId) & e.playlistId.equals(id)))
              .getSingleOrNull();
      if (entry == null) {
        throw StateError('Entry $entryId is not in playlist $id');
      }
      final count = playlistEntries.id.count();
      final total =
          (await (selectOnly(playlistEntries)
                    ..addColumns([count])
                    ..where(playlistEntries.playlistId.equals(id)))
                  .getSingle())
              .read(count)!;
      final from = entry.position;
      final target = to.clamp(0, total - 1);
      if (from == target) return;
      // Shift the rows between the old and the new place by one, then drop
      // the entry into the gap.
      await customUpdate(
        from < target
            ? 'UPDATE playlist_entries SET position = position - 1 '
                  'WHERE playlist_id = ?1 AND position > ?2 AND position <= ?3'
            : 'UPDATE playlist_entries SET position = position + 1 '
                  'WHERE playlist_id = ?1 AND position >= ?3 AND position < ?2',
        variables: [
          Variable.withInt(id),
          Variable.withInt(from),
          Variable.withInt(target),
        ],
        updates: {playlistEntries},
        updateKind: UpdateKind.update,
      );
      await (update(playlistEntries)..where((e) => e.id.equals(entryId))).write(
        PlaylistEntriesCompanion(position: Value(target)),
      );
    });
  }

  Future<void> _append(int id, List<String> paths, {required int start}) async {
    if (paths.isEmpty) return;
    await batch((b) {
      b.insertAll(playlistEntries, [
        for (var i = 0; i < paths.length; i++)
          PlaylistEntriesCompanion.insert(
            playlistId: id,
            path: paths[i],
            position: start + i,
          ),
      ]);
    });
  }
}

String _validName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be blank');
  }
  return trimmed;
}
