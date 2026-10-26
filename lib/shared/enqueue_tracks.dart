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
import 'play_tracks.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';
import 'widgets/app_snack_bar.dart';

final _log = Logger('library');

/// A queue snackbar shown or waiting behind other messages.
class _PendingMessage {
  _PendingMessage(this.text, this.messenger);

  /// The text on the snackbar; changing it updates the snackbar in place.
  final ValueNotifier<String> text;
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;

  /// The snackbar has finished appearing, which is when its time on screen
  /// starts running: from then on a new text would not get a time of its own.
  bool visible = false;
}

/// Tail of the library-level enqueues: each one waits for the one before, so
/// two quick menu picks land in the queue in click order even when their
/// database reads finish in another order. Also holds the queue message still
/// on its way to the screen, so a newer one replaces it instead of piling up.
class _EnqueueChain {
  Future<void> tail = Future.value();

  /// The queue snackbar not gone yet. Null once it is.
  _PendingMessage? pending;
}

final _enqueueChainProvider = Provider<_EnqueueChain>((ref) => _EnqueueChain());

/// Resolves once every library-level enqueue started so far has finished.
/// A caller about to act on the queue awaits it first, so an earlier pick
/// still reading from the database is not overtaken by what comes after.
Future<void> pendingQueuePicks(WidgetRef ref) =>
    ref.read(_enqueueChainProvider).tail;

/// Says [text] in a snackbar. While an earlier queue message waits its turn on
/// the same [messenger], its text is replaced instead: only the latest pick is
/// worth reading. One already on screen is closed and the new text gets a
/// snackbar, and so a time on screen, of its own. Other messages (a finished
/// scan) are never touched.
void _showQueueMessage(
  _EnqueueChain chain,
  ScaffoldMessengerState messenger,
  String text,
) {
  final earlier = chain.pending;
  if (earlier != null && identical(earlier.messenger, messenger)) {
    if (!earlier.visible) {
      earlier.text.value = text;
      return;
    }
    chain.pending = null;
    earlier.controller.close();
  }
  final message = _PendingMessage(ValueNotifier(text), messenger);
  message.controller = messenger.showSnackBar(
    SnackBar(
      onVisible: () => message.visible = true,
      content: ValueListenableBuilder<String>(
        valueListenable: message.text,
        builder: (_, value, _) =>
            AppSnackBarContent(kind: AppSnackBarKind.success, title: value),
      ),
    ),
  );
  chain.pending = message;
  unawaited(
    message.controller.closed.then((_) {
      if (identical(chain.pending, message)) chain.pending = null;
      message.text.dispose();
    }),
  );
}

/// Puts the tracks [read] returns behind the playing one ([QueueAction.playNext])
/// or at the end of the queue, then says so in a snackbar naming [label]
/// (or that [label] is playing, when the queue was empty and it started).
/// Runs after every earlier call, whatever happened to them. Everything it
/// needs from the widget tree ([messenger], [l10n]) is passed in, as the
/// caller may be gone by the time the read finishes. [QueueAction.addToPlaylist] is not a queue action:
/// `enqueueLoaded` and `enqueueFromDatabase` handle it, and passing it here
/// throws [ArgumentError].
Future<void> enqueueTracks(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  QueueAction action,
  Future<List<Track>> Function() read,
  String label,
) {
  if (action == QueueAction.addToPlaylist) {
    throw ArgumentError.value(action, 'action', 'not a queue action');
  }
  final chain = ref.read(_enqueueChainProvider);
  final player = ref.read(playerServiceProvider.notifier);
  Future<void> attempt() async {
    final String text;
    try {
      final tracks = await read();
      // The album or artist vanished in a rescan: nothing to queue.
      if (tracks.isEmpty) return;
      // The guard on entry leaves just these two.
      final next = action == QueueAction.playNext;
      final started = next
          ? await player.playNext(tracks)
          : await player.addToQueue(tracks);
      text = started
          ? l10n.queuePlaying(label)
          : next
          ? l10n.queuePlayingNext(label)
          : l10n.queueAddedToQueue(label);
    } catch (error, stackTrace) {
      _log.severe('Queuing tracks failed', error, stackTrace);
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
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
  if (action == QueueAction.addToPlaylist) {
    // Library tracks carry their file path as uri.
    unawaited(
      addTracksToPlaylist(
        ref,
        context,
        () async => [for (final t in tracks) ?localPathOf(t.uri)],
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
