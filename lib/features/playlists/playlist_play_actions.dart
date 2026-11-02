import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_database.dart' show LibraryDatabase;
import '../../core/database/playlist_page_queries.dart';
import '../../core/player/track.dart' as player;
import '../../shared/enqueue_from_database.dart';
import 'playlist_page_actions.dart' show playlistTrack;

/// The songs of playlist [id] that are in the library, in the playlist's
/// order, as queue entries. Entries whose file is not in the library are
/// left out.
Future<List<player.Track>> readPlaylistQueue(
  LibraryDatabase db,
  int id,
  String? covers,
) async => [
  for (final p in await db.playlistPlayableTracks(id))
    playlistTrack(p.track, covers),
];

/// Replaces the queue with the playable songs of playlist [id] and plays from
/// the first ([shuffle]: shuffled), for a caller with no live `WidgetRef`
/// (the playlist modal, which runs after its row is gone). See
/// [playFromDatabaseIn].
Future<void> playPlaylistIn(
  ProviderContainer container,
  int id, {
  bool shuffle = false,
}) => playFromDatabaseIn(
  container,
  'Playing a playlist failed',
  (db, covers) => readPlaylistQueue(db, id, covers),
  shuffle: shuffle,
);
