import 'dart:async';

import 'package:flutter/painting.dart' show Offset;
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_favorites.dart';
import '../../core/lyrics/online/lyrics_target.dart';
import '../queue_host.dart';
import '../track_menu_actions.dart';
import '../track_menu_choice.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import '../widgets/queue_actions_menu.dart';
import 'song_modal_data.dart';

/// Whether [path] is in Favorites, read from a stream opened for this modal:
/// the shared favorites stream pauses while no heart is on screen and may
/// hold a stale value when the modal opens. Null while the first read is
/// pending.
final songModalIsFavoriteProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, path) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(false);
      return db.watchFavoritePaths().map((paths) => paths.contains(path));
    });

/// What one open song modal holds: a snapshot of the song and everything
/// its actions need from the widget tree, captured before the modal opened.
/// The row may be rebuilt away (a rescan) while the modal is open, so
/// nothing here refers to the row's own `BuildContext`.
class SongModalSession {
  const SongModalSession({
    required this.song,
    required this.runner,
    required this.onQueueAction,
    required this.lyricsTarget,
    this.queueHost,
    this.showAlbum = true,
    this.extraActions = const [],
  });

  final TrackListItem song;
  final TrackMenuRunner runner;
  final ValueChanged<QueueAction> onQueueAction;

  /// Captured before the modal opened; queue actions run with it because the
  /// row that opened the modal can be gone when one is picked.
  final QueueHost? queueHost;

  /// Runs a queue action of the footer or Add to playlist.
  void queue(QueueAction action) =>
      QueueHost.run(queueHost, () => onQueueAction(action));

  /// What Find lyrics online searches for; null leaves that action out.
  final LyricsTarget? lyricsTarget;
  final bool showAlbum;

  /// Actions of the screen the song is listed on (remove from the queue, ...),
  /// shown before the links.
  final List<ContextModalAction> extraActions;

  void _run(TrackMenuChoice choice) => unawaited(
    runner.run(
      choice,
      trackId: song.id,
      path: song.path,
      position: Offset.zero,
      lyricsTarget: lyricsTarget,
    ),
  );

  /// The callbacks the actions call once the modal is closed; [openAdvanced]
  /// pushes a page and so needs the modal's own navigation.
  SongModalHandlers handlers({
    void Function(ContextModalNav nav)? openAdvanced,
  }) => SongModalHandlers(
    openAdvanced: openAdvanced,
    goToAlbum: () => _run(const ShowAlbumChoice()),
    goToArtist: (key) => unawaited(runner.openArtist(key, trackId: song.id)),
    goToFolder: () => _run(const ShowFolderChoice()),
    showInFileManager: () => _run(const ShowInFileManagerChoice()),
    addToPlaylist: () => queue(QueueAction.addToPlaylist),
    setFavorite: (favorite) => _run(FavoriteChoice(favorite: favorite)),
    findLyrics: () => _run(const FindLyricsChoice()),
  );
}
