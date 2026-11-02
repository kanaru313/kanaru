import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_browse_queries.dart';
import '../core/database/library_database.dart' show AlbumKey, LibraryDatabase;
import '../core/database/library_startup.dart';
import '../core/player/player_service.dart';
import '../core/player/playing_track_art.dart' show localPathOf;
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'enqueue_chain.dart';
import 'play_tracks.dart';
import 'queue_host.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';

final _log = Logger('library');

/// Reads the tracks of album [key] in the order of its page.
Future<List<Track>> Function(LibraryDatabase db, String? covers) _albumTracks(
  AlbumKey key,
) =>
    (db, covers) async => [
      for (final t in await db.albumTracks(key)) trackFromRow(t, covers),
    ];

/// [enqueueTracks] for an album, whose tracks are read from the database
/// when its turn comes, in the order of its page.
void enqueueAlbum(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  AlbumKey key,
  String title,
) => enqueueFromDatabase(ref, context, action, title, _albumTracks(key));

/// Replaces the queue with the tracks of album [key], in the order of its
/// page, and plays from the first; see [playFromDatabase].
Future<void> playAlbum(WidgetRef ref, AlbumKey key) =>
    playFromDatabase(ref, 'Playing an album failed', _albumTracks(key));

/// Replaces the queue with the tracks [read] returns and plays from the
/// first. Waits for the queue picks started before it, so it is not
/// overtaken by them, and drops its tracks when a newer action changed the
/// queue while they were read. Does nothing when no library is open or
/// [read] finds no tracks; a failure is logged as [failure].
Future<void> playFromDatabase(
  WidgetRef ref,
  String failure,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  // Read before any await: the row that asked may be gone by then.
  return _playFromDatabase(
    db,
    ref.read(coverCacheDirectoryProvider),
    ref.read(playerServiceProvider.notifier),
    pendingQueuePicks(ref),
    failure,
    read,
    false,
  );
}

/// [playFromDatabase] for a caller with no live [WidgetRef]: everything is
/// read from [container], which outlives any row. [shuffle] turns shuffle on
/// and starts from a random track.
Future<void> playFromDatabaseIn(
  ProviderContainer container,
  String failure,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read, {
  bool shuffle = false,
}) async {
  final db = container.read(libraryDatabaseProvider);
  if (db == null) return;
  return _playFromDatabase(
    db,
    container.read(coverCacheDirectoryProvider),
    container.read(playerServiceProvider.notifier),
    pendingQueuePicksIn(container),
    failure,
    read,
    shuffle,
  );
}

/// [playAlbum] (or its shuffled form) for a caller with no live [WidgetRef],
/// such as a modal action that runs after the tile is gone.
Future<void> playAlbumIn(
  ProviderContainer container,
  AlbumKey key, {
  bool shuffle = false,
}) => playFromDatabaseIn(
  container,
  'Playing an album failed',
  _albumTracks(key),
  shuffle: shuffle,
);

Future<void> _playFromDatabase(
  LibraryDatabase db,
  String? covers,
  PlayerService player,
  Future<void> picks,
  String failure,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read,
  bool shuffle,
) async {
  try {
    await picks;
    final changesBefore = player.userQueueChanges;
    final tracks = await read(db, covers);
    if (tracks.isEmpty || player.userQueueChanges != changesBefore) return;
    if (shuffle) {
      await player.openShuffled(tracks);
    } else {
      await player.openTracks(tracks);
    }
  } catch (error, stackTrace) {
    _log.severe(failure, error, stackTrace);
  }
}

/// Queues the tracks [read] returns, naming them [label]; see [enqueueTracks].
/// [read] gets the open library and the cover cache directory (null when
/// covers are off). Inside a [QueueHost] zone the host does the work. Otherwise
/// does nothing, silently, when [context] is unmounted or no library is open.
void enqueueFromDatabase(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String label,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read,
) {
  // A modal's queue action runs after its tile is gone: the host then does
  // the work, before the unmounted context would drop it.
  final host = QueueHost.current;
  if (host != null) {
    host.enqueueFromDatabase(action, label, read);
    return;
  }
  if (!context.mounted) return;
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
  if (action == QueueAction.addToPlaylist) {
    unawaited(
      addTracksToPlaylist(
        ref,
        context,
        () async => [
          for (final t in await read(db, covers)) ?localPathOf(t.uri),
        ],
        label,
      ),
    );
    return;
  }
  unawaited(
    enqueueTracks(
      ref,
      ScaffoldMessenger.of(context),
      context.l10n,
      action,
      () => read(db, covers),
      label,
    ),
  );
}
