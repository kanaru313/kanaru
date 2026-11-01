import 'dart:async';

import 'package:flutter/foundation.dart' show ValueChanged;

import '../enqueue_from_database.dart';
import '../library_route_keys.dart';
import '../queue_host.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/queue_actions_menu.dart';
import 'album_modal_data.dart';

/// What one open album modal holds: a snapshot of the album and everything
/// its actions need from the widget tree, captured before the modal opened.
/// The tile may be rebuilt away while the modal is open, so nothing here
/// refers to the tile's own `BuildContext`.
class AlbumModalSession {
  const AlbumModalSession({
    required this.album,
    required this.runner,
    required this.onQueueAction,
    this.showAlbum = true,
  });

  final AlbumTileData album;
  final TrackMenuRunner runner;
  final ValueChanged<QueueAction> onQueueAction;

  /// False on the page of the album itself.
  final bool showAlbum;

  /// Runs a queue action of the footer or Add to playlist.
  void queue(QueueAction action) =>
      QueueHost.run(runner.queueHost, () => onQueueAction(action));

  /// The callbacks the actions call once the modal is closed. The page
  /// openers push a page and so need the modal's own navigation.
  AlbumModalHandlers handlers({
    void Function(ContextModalNav nav)? openArtists,
    void Function(ContextModalNav nav)? openFolders,
    void Function(ContextModalNav nav)? openAdvanced,
  }) => AlbumModalHandlers(
    openArtists: openArtists,
    openFolders: openFolders,
    openAdvanced: openAdvanced,
    goToAlbum: () => runner.goTo(albumLocation(album.key)),
    goToArtist: (key) => runner.goTo(artistLocation(key)),
    goToFolder: (path) => runner.goTo(folderLocation(path)),
    showInFileManager: (sample) => runner.showInFileManagerAt(sample),
    playAll: () => playAlbumIn(runner.container, album.key),
    shuffle: () => playAlbumIn(runner.container, album.key, shuffle: true),
    addToPlaylist: () => queue(QueueAction.addToPlaylist),
    addAllToFavorites: () =>
        unawaited(runner.addAlbumToFavorites(album.key, album.title)),
  );
}
