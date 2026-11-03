import 'package:flutter/widgets.dart' show ValueChanged, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncValue;

import '../../core/database/library_database.dart' show AlbumKey;
import '../../l10n/l10n.dart';
import '../genre_display_name.dart';
import '../genre_summaries.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import 'genre_modal_links.dart';

/// What the actions page needs to know about the genre, to decide which rows
/// show and which are greyed out.
class GenreModalData {
  const GenreModalData({
    required this.genre,
    required this.links,
    this.showGenre = true,
    this.gone = false,
  });

  /// The row or tile the modal was opened from.
  final GenreSummary genre;

  /// Null while the links load, or when no song has the genre any more:
  /// the album and folder rows are then greyed out.
  final GenreLinks? links;

  /// False on the page of the genre itself.
  final bool showGenre;

  /// The links were read and no song has the genre any more: the rows
  /// that play or copy it are greyed out. False while the links load.
  final bool gone;

  /// Whether [links] resolved to no genre; loading and errors are not gone.
  static bool goneOf(AsyncValue<GenreLinks?> links) =>
      links is AsyncData<GenreLinks?> && links.value == null;

  /// The name shown: translated "Unknown genre" for the tracks with no tag,
  /// else the preferred spelling.
  String displayName(AppLocalizations l10n) =>
      genreDisplayName(l10n, genre.key, genre.name);

  /// Number of albums with songs of this genre once loaded; null while loading.
  int? get albumCount => links?.albums.length;

  /// Total duration of the songs of this genre once loaded; null while loading.
  int? get durationMs => links?.durationMs;
}

/// What the actions do. Each one runs after the modal has closed, except
/// [openAlbums], [openFolders] and [openAdvanced], which push a page.
class GenreModalHandlers {
  const GenreModalHandlers({
    required this.goToGenre,
    required this.goToAlbum,
    required this.goToFolder,
    required this.showInFileManager,
    required this.playAll,
    required this.shuffle,
    required this.addToPlaylist,
    required this.addAllToFavorites,
    this.openAlbums,
    this.openFolders,
    this.openAdvanced,
  });

  final VoidCallback goToGenre;

  /// Opens the album under the genre's page.
  final ValueChanged<AlbumKey> goToAlbum;
  final ValueChanged<String> goToFolder;

  /// Shows the file at the given path in the file manager.
  final ValueChanged<String> showInFileManager;
  final VoidCallback playAll;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;

  /// Puts every local song of the genre in Favorites, saying how many went in.
  final VoidCallback addAllToFavorites;
  final void Function(ContextModalNav nav)? openAlbums;
  final void Function(ContextModalNav nav)? openFolders;
  final void Function(ContextModalNav nav)? openAdvanced;
}
