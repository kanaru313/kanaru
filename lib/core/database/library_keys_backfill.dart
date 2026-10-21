import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';

import 'library_database.dart';
import 'text_keys.dart';
import 'track_keys.dart';

final _log = Logger('library.keys');

/// Rows keyed per transaction: short enough that scans and playback queries
/// never wait long for the write lock.
const keysBackfillChunkSize = 2000;

/// Keys every track whose `keys_version` is below [version], in chunks by id,
/// and returns how many it keyed. Resumable: a chunk commits as a whole, so
/// an interrupted run leaves the rest for the next one. Re-keying after a
/// rule change is the same call with a higher [version].
///
/// A row whose keys cannot be made or written is logged and left at its old
/// version; it never stops the run. [onProgress] gets (done, total) after each
/// chunk, `total` being the rows found stale when the run began.
Future<int> backfillLibraryKeys(
  LibraryDatabase db, {
  int version = textKeysVersion,
  int chunkSize = keysBackfillChunkSize,
  void Function(int done, int total)? onProgress,
  @visibleForTesting Future<void> Function()? afterRead,
}) async {
  final total = await countStaleKeys(db, version);
  onProgress?.call(0, total);
  var done = 0;
  var lastId = 0;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT id, title, artist, album, album_artist, genre FROM tracks '
          'WHERE id > ?1 AND keys_version < ?2 ORDER BY id LIMIT ?3',
          variables: [
            Variable.withInt(lastId),
            Variable.withInt(version),
            Variable.withInt(chunkSize),
          ],
        )
        .get();
    if (rows.isEmpty) {
      // Lists that sort by the keys re-read once, not after every chunk.
      if (done > 0) {
        db.notifyUpdates({
          const TableUpdate('tracks', kind: UpdateKind.update),
        });
      }
      return done;
    }
    lastId = rows.last.read<int>('id');
    final keyed = <(int, TrackKeys, List<Object?>)>[];
    for (final row in rows) {
      final id = row.read<int>('id');
      final tags = <Object?>[
        row.read<String>('title'),
        row.readNullable<String>('artist'),
        row.readNullable<String>('album'),
        row.readNullable<String>('album_artist'),
        row.readNullable<String>('genre'),
      ];
      try {
        keyed.add((
          id,
          trackKeysFor(
            title: tags[0]! as String,
            artist: tags[1] as String?,
            album: tags[2] as String?,
            albumArtist: tags[3] as String?,
            genre: tags[4] as String?,
          ),
          tags,
        ));
      } catch (error, stackTrace) {
        _log.warning('Keys of track $id skipped', error, stackTrace);
      }
    }
    await afterRead?.call();
    try {
      await db.transaction(() => _writeChunk(db, keyed, version));
    } catch (error, stackTrace) {
      // One row the database refuses must not cost the whole chunk: write the
      // rows one by one and skip the bad ones.
      _log.warning('Keys chunk failed, retrying per row', error, stackTrace);
      for (final entry in keyed) {
        try {
          await db.transaction(() => _writeChunk(db, [entry], version));
        } catch (error, stackTrace) {
          _log.warning('Keys of track ${entry.$1} skipped', error, stackTrace);
        }
      }
    }
    done += rows.length;
    onProgress?.call(done, total);
  }
}

/// How many tracks have keys older than [version].
Future<int> countStaleKeys(LibraryDatabase db, int version) async {
  final row = await db
      .customSelect(
        'SELECT count(*) AS n FROM tracks WHERE keys_version < ?1',
        variables: [Variable.withInt(version)],
      )
      .getSingle();
  return row.read<int>('n');
}

/// Replaces the keys and `track_artists` rows of [chunk]; the caller wraps
/// it in a transaction.
///
/// Tags were read before this transaction, so every write is conditional on
/// the row still holding those tags and an older version: a track a scan
/// changed in between keeps its stale version for a later pass, and a track
/// deleted in between is left alone (its credits would break the foreign
/// key).
Future<void> _writeChunk(
  LibraryDatabase db,
  List<(int, TrackKeys, List<Object?>)> chunk,
  int version,
) async {
  // True while the row at `?` (id) still has the tags read earlier and the
  // keys of [version]; used after the update to guard the credit rows.
  const keyed =
      'EXISTS (SELECT 1 FROM tracks WHERE id = ? AND keys_version = ? '
      'AND title IS ? AND artist IS ? AND album IS ? AND album_artist IS ? '
      'AND genre IS ?)';
  await db.batch((b) {
    for (final (id, keys, tags) in chunk) {
      b.customStatement(
        'UPDATE tracks SET album_artist_key = ?, album_title_key = ?, '
        'album_display_artist = ?, title_sort = ?, artist_sort = ?, '
        'album_sort = ?, artist_search = ?, album_search = ?, '
        'album_artist_search = ?, genre_search = ?, keys_version = ? '
        'WHERE id = ? AND keys_version < ? AND title IS ? AND artist IS ? '
        'AND album IS ? AND album_artist IS ? AND genre IS ?',
        [
          keys.albumArtistKey,
          keys.albumTitleKey,
          keys.albumDisplayArtist,
          keys.titleSort,
          keys.artistSort,
          keys.albumSort,
          keys.artistSearch,
          keys.albumSearch,
          keys.albumArtistSearch,
          keys.genreSearch,
          version,
          id,
          version,
          ...tags,
        ],
      );
      b.customStatement(
        'DELETE FROM track_artists WHERE track_id = ? AND $keyed',
        [id, id, version, ...tags],
      );
      for (final artist in keys.artists) {
        b.customStatement(
          'INSERT OR IGNORE INTO track_artists '
          '(track_id, artist_key, artist_name) '
          'SELECT ?, ?, ? WHERE $keyed',
          [id, artist.key, artist.name, id, version, ...tags],
        );
      }
    }
  });
}
