import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_queries.dart';
import '../../core/database/library_database.dart'
    show AlbumKey, BrowseTrack, LibraryDatabase;
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/player_service.dart';
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';
import 'artists/artist_page_sections.dart';
import 'widgets/queue_actions_menu.dart';

final _log = Logger('library');

/// A queue entry for a library row. [artPath] is the row's cover thumbnail
/// (see `coverPath`), shown by the player and published over MPRIS; null
/// when the track has no cover or covers are off.
Track trackFromItem({
  required String path,
  required String title,
  String? artist,
  int? durationMs,
  String? artPath,
}) => Track(
  uri: path,
  title: title,
  artist: artist,
  artUri: artPath,
  duration: durationMs == null ? null : Duration(milliseconds: durationMs),
);

/// A queue entry for a track of the album or artist pages, with [artPath]
/// as in [trackFromItem].
Track trackFromBrowse(BrowseTrack track, {String? artPath}) => trackFromItem(
  path: track.path,
  title: track.title,
  artist: track.artist,
  durationMs: track.durationMs,
  artPath: artPath,
);

/// Replaces the queue with [tracks] and plays from [start]: tapping a row
/// plays its whole context (list, album, artist).
void playTracks(WidgetRef ref, List<Track> tracks, int start) => unawaited(
  ref.read(playerServiceProvider.notifier).openTracks(tracks, start: start),
);

/// Tail of the library-level enqueues: each one waits for the one before, so
/// two quick menu picks land in the queue in click order even when their
/// database reads finish in another order.
class _EnqueueChain {
  Future<void> tail = Future.value();
}

final _enqueueChainProvider = Provider<_EnqueueChain>((ref) => _EnqueueChain());

/// Puts the tracks [read] returns behind the playing one ([QueueAction.playNext])
/// or at the end of the queue, then says so in a snackbar naming [label].
/// Runs after every earlier call. Everything it needs from the widget tree
/// ([messenger], [l10n]) is passed in, as the caller may be gone by the time
/// the read finishes.
Future<void> enqueueTracks(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  QueueAction action,
  Future<List<Track>> Function() read,
  String label,
) {
  final chain = ref.read(_enqueueChainProvider);
  final player = ref.read(playerServiceProvider.notifier);
  final run = chain.tail.then((_) async {
    try {
      final tracks = await read();
      // The album or artist vanished in a rescan: nothing to queue.
      if (tracks.isEmpty) return;
      switch (action) {
        case QueueAction.playNext:
          await player.playNext(tracks);
        case QueueAction.addToQueue:
          await player.addToQueue(tracks);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              QueueAction.playNext => l10n.queuePlayingNext(label),
              QueueAction.addToQueue => l10n.queueAddedToQueue(label),
            }),
          ),
        );
    } catch (error, stackTrace) {
      _log.severe('Queuing tracks failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryUnexpectedError)),
      );
    }
  });
  chain.tail = run;
  return run;
}

/// [enqueueTracks] for tracks already at hand, naming them [label].
void enqueueLoaded(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  List<Track> tracks,
  String label,
) => unawaited(
  enqueueTracks(
    ref,
    ScaffoldMessenger.of(context),
    context.l10n,
    action,
    () async => tracks,
    label,
  ),
);

/// [enqueueTracks] for an album, whose tracks are read from the database
/// when its turn comes, in the order of its page.
void enqueueAlbum(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  AlbumKey key,
  String title,
) => _enqueueFromDatabase(
  ref,
  context,
  action,
  title,
  (db, covers) async => [
    for (final t in await db.albumTracks(key))
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ],
);

/// [enqueueTracks] for an artist: the songs of their page, in its order.
void enqueueArtist(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String artistKey,
  String name,
) => _enqueueFromDatabase(ref, context, action, name, (db, covers) async {
  final (tracks, albums) = await db.transaction(
    () => (db.artistTracks(artistKey), db.artistAlbums(artistKey)).wait,
  );
  if (tracks.isEmpty) return const [];
  return [
    for (final t in ArtistPageSections.fromTracks(
      artistKey,
      tracks,
      albums,
    ).songs)
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ];
});

void _enqueueFromDatabase(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String label,
  Future<List<Track>> Function(LibraryDatabase db, String? covers) read,
) {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
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
