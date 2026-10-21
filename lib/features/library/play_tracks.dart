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
import 'artists/artist_page_data.dart';
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
/// database reads finish in another order. Also holds the queue message still
/// on its way to the screen, so a newer one replaces it instead of piling up.
class _EnqueueChain {
  Future<void> tail = Future.value();

  /// The text of the queue snackbar shown or waiting behind other messages,
  /// and the messenger it belongs to. Null once it is gone.
  ValueNotifier<String>? pendingMessage;
  ScaffoldMessengerState? pendingMessenger;
}

final _enqueueChainProvider = Provider<_EnqueueChain>((ref) => _EnqueueChain());

/// Says [text] in a snackbar. While an earlier queue message is still showing
/// or waiting its turn on the same [messenger], its text is replaced instead:
/// only the latest pick is worth reading, and other messages (a finished
/// scan) are never touched.
void _showQueueMessage(
  _EnqueueChain chain,
  ScaffoldMessengerState messenger,
  String text,
) {
  final pending = chain.pendingMessage;
  if (pending != null && identical(chain.pendingMessenger, messenger)) {
    pending.value = text;
    return;
  }
  final message = ValueNotifier(text);
  final controller = messenger.showSnackBar(
    SnackBar(
      content: ValueListenableBuilder<String>(
        valueListenable: message,
        builder: (_, value, _) => Text(value),
      ),
    ),
  );
  chain.pendingMessage = message;
  chain.pendingMessenger = messenger;
  unawaited(
    controller.closed.then((_) {
      if (identical(chain.pendingMessage, message)) {
        chain.pendingMessage = null;
        chain.pendingMessenger = null;
      }
      message.dispose();
    }),
  );
}

/// Puts the tracks [read] returns behind the playing one ([QueueAction.playNext])
/// or at the end of the queue, then says so in a snackbar naming [label]
/// (or that [label] is playing, when the queue was empty and it started).
/// Runs after every earlier call, whatever happened to them. Everything it needs from the widget tree
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
  Future<void> attempt() async {
    final String text;
    try {
      final tracks = await read();
      // The album or artist vanished in a rescan: nothing to queue.
      if (tracks.isEmpty) return;
      final started = switch (action) {
        QueueAction.playNext => await player.playNext(tracks),
        QueueAction.addToQueue => await player.addToQueue(tracks),
      };
      text = started
          ? l10n.queuePlaying(label)
          : switch (action) {
              QueueAction.playNext => l10n.queuePlayingNext(label),
              QueueAction.addToQueue => l10n.queueAddedToQueue(label),
            };
    } catch (error, stackTrace) {
      _log.severe('Queuing tracks failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryUnexpectedError)),
      );
      return;
    }
    // The tracks are queued: failing to say so is no queuing failure.
    try {
      _showQueueMessage(chain, messenger, text);
    } catch (error, stackTrace) {
      _log.warning('Showing the queue message failed', error, stackTrace);
    }
  }

  // Reporting the failure can fail too (the messenger may be gone): that must
  // not leave the chain rejected, or no later pick would ever run.
  final run = chain.tail.then((_) => attempt()).catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _log.severe('Reporting a queuing failure failed', error, stackTrace);
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
) {
  // The menu closes later than it opened: its page may be gone by then.
  if (!context.mounted) return;
  unawaited(
    enqueueTracks(
      ref,
      ScaffoldMessenger.of(context),
      context.l10n,
      action,
      () async => tracks,
      label,
    ),
  );
}

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
  final sections = await readArtistSections(db, artistKey);
  return [
    for (final t in sections?.songs ?? const <BrowseTrack>[])
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
  if (!context.mounted) return;
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
