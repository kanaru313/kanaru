import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show LibraryDatabase;
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_page_queries.dart';
import '../../core/database/playlist_rows.dart';
import '../../core/player/track.dart' as player;
import '../../l10n/l10n.dart';
import '../../shared/enqueue_from_database.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_display_name.dart';
import 'playlist_page_actions.dart' show playableStartIndex;

final _log = Logger('playlists');

/// The songs of playlist [id] that are in the library, in the playlist's
/// order, as queue entries. Entries whose file is not in the library are
/// left out.
Future<List<player.Track>> readPlaylistQueue(
  LibraryDatabase db,
  int id,
  String? covers,
) async => [
  for (final p in await db.playlistPlayableTracks(id))
    trackFromRow(p.track, covers),
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

/// Reads the playable tracks of playlist [id] and opens them as the queue,
/// starting at the entry [entryId] (see [playableStartIndex]). When
/// [isMounted] turns false before the read ends (the page was left), nothing
/// plays.
Future<void> playPlaylistFrom(
  WidgetRef ref,
  BuildContext context,
  bool Function() isMounted,
  int id,
  int? entryId,
  int indexHint,
) async {
  // Everything the widget tree gives is taken before the first await: the
  // page may be gone when the read ends.
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final playable = await db.playlistPlayableTracks(id);
    if (!isMounted()) return;
    final start = playableStartIndex(playable, entryId, indexHint);
    if (start == null) return;
    playTracks(ref, [
      for (final p in playable) trackFromRow(p.track, covers),
    ], start);
  } catch (error, stack) {
    _log.severe('Reading the play queue failed', error, stack);
    if (isMounted()) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
    }
  }
}

/// Reads the playable tracks of playlist [id] and shuffles them into the
/// queue. Leaving the page before the read ends plays nothing.
Future<void> shufflePlaylist(
  WidgetRef ref,
  BuildContext context,
  bool Function() isMounted,
  int id,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final covers = ref.read(coverCacheDirectoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final playable = await db.playlistPlayableTracks(id);
    if (!isMounted() || playable.isEmpty) return;
    shuffleTracks(ref, [
      for (final p in playable) trackFromRow(p.track, covers),
    ]);
  } catch (error, stack) {
    _log.severe('Reading the shuffle queue failed', error, stack);
    if (isMounted()) {
      messenger.showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.error,
          title: l10n.libraryUnexpectedError,
        ),
      );
    }
  }
}

/// A queue menu pick for every playable song of [playlist], read when the
/// pick's turn comes.
void queuePlaylist(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  PlaylistSummary playlist,
) {
  enqueueFromDatabase(
    ref,
    context,
    action,
    playlistDisplayName(playlist, context.l10n),
    (db, covers) => readPlaylistQueue(db, playlist.id, covers),
  );
}
