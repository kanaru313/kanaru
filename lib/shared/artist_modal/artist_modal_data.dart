import 'package:flutter/widgets.dart' show ValueChanged, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncValue;

import '../artist_summaries.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../../core/database/library_database.dart' show AlbumKey;
import 'artist_modal_links.dart';

/// What the actions page needs to know about the artist, to decide which rows
/// show and which are greyed out.
class ArtistModalData {
  const ArtistModalData({
    required this.artist,
    required this.links,
    this.showArtist = true,
    this.gone = false,
  });

  /// The row the modal was opened from; counts in the header come from it.
  final ArtistSummary artist;

  /// Null while the links load, or when no song credits the artist any more:
  /// the album and folder rows are then greyed out.
  final ArtistLinks? links;

  /// False on the page of the artist itself.
  final bool showArtist;

  /// The links were read and no song credits the artist any more: the rows
  /// that play or copy it are greyed out. False while the links load.
  final bool gone;

  /// Whether [links] resolved to no artist; loading and errors are not gone.
  static bool goneOf(AsyncValue<ArtistLinks?> links) =>
      links is AsyncData<ArtistLinks?> && links.value == null;

  /// The name shown: the one the page of the artist uses once loaded, else
  /// the one of the row.
  String get displayName => links?.sections.name ?? artist.name;
}

/// What the actions do. Each one runs after the modal has closed, except
/// [openAlbums], [openFolders] and [openAdvanced], which push a page.
class ArtistModalHandlers {
  const ArtistModalHandlers({
    required this.goToArtist,
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

  final VoidCallback goToArtist;

  /// Opens the album under the artist's page.
  final ValueChanged<AlbumKey> goToAlbum;
  final ValueChanged<String> goToFolder;

  /// Shows the file at the given path in the file manager.
  final ValueChanged<String> showInFileManager;
  final VoidCallback playAll;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;

  /// Puts every local song of the artist in Favorites, saying how many went in.
  final VoidCallback addAllToFavorites;
  final void Function(ContextModalNav nav)? openAlbums;
  final void Function(ContextModalNav nav)? openFolders;
  final void Function(ContextModalNav nav)? openAdvanced;
}
