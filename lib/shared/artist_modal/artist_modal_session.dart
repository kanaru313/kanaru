import 'dart:async';

import 'package:flutter/foundation.dart' show ValueChanged;

import '../../core/database/library_database.dart' show AlbumKey;
import '../../core/player/playing_track_art.dart' show localPathOf;
import '../artist_page/enqueue_artist.dart';
import '../artist_page/read_artist_sections.dart';
import '../artist_summaries.dart';
import '../library_route_keys.dart';
import '../queue_host.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/queue_actions_menu.dart';
import 'artist_modal_data.dart';

/// What one open artist modal holds: a snapshot of the artist and everything
/// its actions need from the widget tree, captured before the modal opened.
/// The row may be rebuilt away while the modal is open, so nothing here
/// refers to the row's own `BuildContext`.
class ArtistModalSession {
  const ArtistModalSession({
    required this.artist,
    required this.runner,
    required this.onQueueAction,
    this.showArtist = true,
  });

  final ArtistSummary artist;
  final TrackMenuRunner runner;
  final ValueChanged<QueueAction> onQueueAction;

  /// False on the page of the artist itself.
  final bool showArtist;

  /// Runs a queue action of the footer or Add to playlist.
  void queue(QueueAction action) =>
      QueueHost.run(runner.queueHost, () => onQueueAction(action));

  /// The callbacks the actions call once the modal is closed. The page
  /// openers push a page and so need the modal's own navigation.
  ArtistModalHandlers handlers({
    void Function(ContextModalNav nav)? openAlbums,
    void Function(ContextModalNav nav)? openFolders,
    void Function(ContextModalNav nav)? openAdvanced,
  }) => ArtistModalHandlers(
    openAlbums: openAlbums,
    openFolders: openFolders,
    openAdvanced: openAdvanced,
    goToArtist: () => runner.goTo(artistLocation(artist.key)),
    goToAlbum: (AlbumKey key) =>
        runner.goTo(artistAlbumLocation(artist.key, key)),
    goToFolder: (path) => runner.goTo(folderLocation(path)),
    showInFileManager: (sample) => runner.showInFileManagerAt(sample),
    playAll: () => unawaited(playArtistIn(runner.container, artist.key)),
    shuffle: () =>
        unawaited(playArtistIn(runner.container, artist.key, shuffle: true)),
    addToPlaylist: () => queue(QueueAction.addToPlaylist),
    addAllToFavorites: () => unawaited(
      runner.addPathsToFavorites(
        (db) async => [
          // Library tracks carry their file path as uri.
          for (final t
              in (await readArtistSections(db, artist.key))?.songs ?? [])
            ?localPathOf(t.path),
        ],
        artist.name,
      ),
    ),
  );
}
