import 'dart:async';

import 'package:flutter/foundation.dart' show ValueChanged;

import '../../core/database/genre_queries.dart';
import '../../core/database/library_database.dart' show AlbumKey;
import '../../core/player/playing_track_art.dart' show localPathOf;
import '../genre_display_name.dart';
import '../genre_page/enqueue_genre.dart';
import '../genre_summaries.dart';
import '../library_route_keys.dart';
import '../queue_host.dart';
import '../track_menu_actions.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/queue_actions_menu.dart';
import 'genre_modal_data.dart';

/// What one open genre modal holds: a snapshot of the genre and everything
/// its actions need from the widget tree, captured before the modal opened.
/// The tile may be rebuilt away while the modal is open, so nothing here
/// refers to the tile's own `BuildContext`.
class GenreModalSession {
  const GenreModalSession({
    required this.genre,
    required this.runner,
    required this.onQueueAction,
    this.showGenre = true,
  });

  final GenreSummary genre;
  final TrackMenuRunner runner;
  final ValueChanged<QueueAction> onQueueAction;

  /// False on the page of the genre itself.
  final bool showGenre;

  /// Runs a queue action of the footer or Add to playlist.
  void queue(QueueAction action) =>
      QueueHost.run(runner.queueHost, () => onQueueAction(action));

  /// The callbacks the actions call once the modal is closed. The page
  /// openers push a page and so need the modal's own navigation.
  GenreModalHandlers handlers({
    void Function(ContextModalNav nav)? openAlbums,
    void Function(ContextModalNav nav)? openFolders,
    void Function(ContextModalNav nav)? openAdvanced,
  }) => GenreModalHandlers(
    openAlbums: openAlbums,
    openFolders: openFolders,
    openAdvanced: openAdvanced,
    goToGenre: () => runner.goTo(genreLocation(genre.key)),
    goToAlbum: (AlbumKey key) =>
        runner.goTo(genreAlbumLocation(genre.key, key)),
    goToFolder: (path) => runner.goTo(folderLocation(path)),
    showInFileManager: (sample) => runner.showInFileManagerAt(sample),
    playAll: () => unawaited(playGenreIn(runner.container, genre)),
    shuffle: () =>
        unawaited(playGenreIn(runner.container, genre, shuffle: true)),
    addToPlaylist: () => queue(QueueAction.addToPlaylist),
    addAllToFavorites: () => unawaited(
      runner.addPathsToFavorites(
        (db) async {
          final tracks = await db.genreTracks(
            genre.raws,
            includeNull: genre.withoutGenre,
          );
          return [for (final t in tracks) ?localPathOf(t.path)];
        },
        genreDisplayName(runner.l10n, genre.key, genre.name),
      ),
    ),
  );
}
