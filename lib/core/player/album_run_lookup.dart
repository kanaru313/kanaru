import 'package:drift/drift.dart';

import '../database/library_database.dart' show LibraryDatabase;
import '../database/text_keys.dart' show textKeysVersion;
import 'replay_gain_options.dart';

/// Album keys of the library tracks at [paths]; a path with no key is left
/// out.
typedef AlbumRunKeyLookup = Future<Map<String, AlbumRunKey>> Function(
  List<String> paths,
);

/// Reads the album key of tracks from [db], one query on the unique
/// `tracks.path` index. Only rows whose keys the current rules produced are
/// returned: a track without an album, or one not keyed yet
/// (`keysVersion < textKeysVersion`, keyed in the background), is no album.
/// It reads `tracks` here, not in `core/database`, because the player is its
/// only user and the playing art already reads the database from here too.
AlbumRunKeyLookup albumKeyLookupFor(LibraryDatabase db) => (paths) async {
  if (paths.isEmpty) return const {};
  final tracks = db.tracks;
  final rows =
      await (db.selectOnly(tracks)
            ..addColumns([
              tracks.path,
              tracks.albumArtistKey,
              tracks.albumTitleKey,
            ])
            ..where(
              tracks.path.isIn(paths) &
                  tracks.albumTitleKey.isNotNull() &
                  tracks.keysVersion.isBiggerOrEqualValue(textKeysVersion),
            ))
          .get();
  return {
    for (final row in rows)
      row.read(tracks.path)!: (
        artist: row.read(tracks.albumArtistKey),
        title: row.read(tracks.albumTitleKey)!,
      ),
  };
};
