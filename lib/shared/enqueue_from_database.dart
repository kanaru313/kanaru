import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_browse_queries.dart';
import '../core/database/library_database.dart' show AlbumKey, LibraryDatabase;
import '../core/database/library_startup.dart';
import '../core/indexer/cover_paths.dart';
import '../core/player/player_service.dart';
import '../core/player/playing_track_art.dart' show localPathOf;
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'enqueue_chain.dart';
import 'play_tracks.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';

final _log = Logger('library');

/// [enqueueTracks] for an album, whose tracks are read from the database
/// when its turn comes, in the order of its page.
void enqueueAlbum(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  AlbumKey key,
  String title,
) => enqueueFromDatabase(
  ref,
  context,
  action,
  title,
  (db, covers) async => [
    for (final t in await db.albumTracks(key))
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ],
);

/// Replaces the queue with the tracks of album [key], in the order of its
/// page, and plays from the first; see [playFromDatabase].
Future<void> playAlbum(WidgetRef ref, AlbumKey key) => playFromDatabase(
  ref,
  'Playing an album failed',
  (db, covers) async => [
    for (final t in await db.albumTracks(key))
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ],
);

/// Replaces the queue with the tracks crediting [artistKey], album by album
/// as Home's artist cards queue them, and plays from the first; see
/// [playFromDatabase]. The artist page orders them by its album tiles, which
/// only the library feature knows.
Future<void> playArtistTracks(WidgetRef ref, String artistKey) =>
    playFromDatabase(
      ref,
      'Playing an artist failed',
      (db, covers) async => [
        for (final t in await db.artistTracks(artistKey))
          trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
      ],
    );

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
  final covers = ref.read(coverCacheDirectoryProvider);
  // Read before any await: the row that asked may be gone by then.
  final player = ref.read(playerServiceProvider.notifier);
  final picks = pendingQueuePicks(ref);
  try {
    await picks;
    final changesBefore = player.userQueueChanges;
    final tracks = await read(db, covers);
    if (tracks.isEmpty || player.userQueueChanges != changesBefore) return;
    await player.openTracks(tracks);
  } catch (error, stackTrace) {
    _log.severe(failure, error, stackTrace);
  }
}

/// Queues the tracks [read] returns, naming them [label]; see [enqueueTracks].
/// [read] gets the open library and the cover cache directory (null when
/// covers are off). Does nothing, silently, when [context] is unmounted or no
/// library is open.
void enqueueFromDatabase(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String label,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read,
) {
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
