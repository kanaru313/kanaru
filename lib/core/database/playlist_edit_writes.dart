import 'package:drift/drift.dart';

import 'library_database.dart';
import 'playlist_text_rules.dart';
import 'playlist_write_helpers.dart';

/// Playlist edit and clean-up writes. Each one is a single transaction.
extension PlaylistEditWrites on LibraryDatabase {
  /// Sets name and description of playlist [id] (both cleaned, see
  /// `cleanPlaylistName`). A blank or over-long name, or an over-long
  /// description, throws [ArgumentError]. Does nothing when the playlist is
  /// gone, is Favorites, or already holds these values (no watcher wakes).
  Future<void> updatePlaylistDetails(
    int id, {
    required String name,
    required String description,
  }) async {
    final cleanName = validPlaylistName(name);
    final cleanDescription = cleanPlaylistDescription(description);
    if (graphemeLength(cleanDescription) > playlistDescriptionMaxLength) {
      throw ArgumentError.value(description, 'description', 'is too long');
    }
    await (update(playlists)..where(
          (p) =>
              p.id.equals(id) &
              p.kind.isNull() &
              (p.name.equals(cleanName).not() |
                  p.description.equals(cleanDescription).not()),
        ))
        .write(
          PlaylistsCompanion(
            name: Value(cleanName),
            description: Value(cleanDescription),
          ),
        );
  }

  /// Copies playlist [id] into a new ordinary playlist named [name] (capped
  /// to the name limit, keeping a trailing " (copy)"-style suffix) and returns
  /// its id; null when the source is gone. The copy keeps the description and
  /// every entry, repeats included. [now] is epoch milliseconds.
  Future<int?> duplicatePlaylist(
    int id, {
    required String name,
    required int now,
  }) async {
    final cleaned = cleanPlaylistName(name);
    if (cleaned.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    final cleanName = capPlaylistName(cleaned);
    return transaction(() async {
      final source = await (select(
        playlists,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (source == null) return null;
      final newId = await into(playlists).insert(
        PlaylistsCompanion.insert(
          name: cleanName,
          createdAt: now,
          description: Value(source.description),
        ),
      );
      await customUpdate(
        '''
INSERT INTO playlist_entries (playlist_id, path, position)
SELECT ?2, path, ROW_NUMBER() OVER (ORDER BY position, id) - 1
FROM playlist_entries WHERE playlist_id = ?1''',
        variables: [Variable.withInt(id), Variable.withInt(newId)],
        updates: {playlistEntries},
        updateKind: UpdateKind.insert,
      );
      return newId;
    });
  }

  /// Deletes every entry of playlist [id] that has an earlier copy of the
  /// same path, keeping the first, closes the gaps and returns how many went.
  /// Nothing to delete: no renumber, no watcher wake.
  Future<int> removeRepeatedEntries(int id) => transaction(() async {
    final deleted = await customUpdate(
      '''
DELETE FROM playlist_entries WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY path ORDER BY position, id) AS r
    FROM playlist_entries WHERE playlist_id = ?1
  ) WHERE r > 1)''',
      variables: [Variable.withInt(id)],
    );
    // The statement declares no tables: drift would announce a write even
    // when nothing matched. The renumber below announces the change.
    if (deleted == 0) return 0;
    await renumberPlaylist(id);
    return deleted;
  });
}
