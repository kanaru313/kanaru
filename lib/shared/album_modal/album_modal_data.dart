import 'package:flutter/widgets.dart' show ValueChanged, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncValue;

import '../../core/database/library_browse_album_links.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/library_grid/album_tile_data.dart';

/// What the actions page needs to know about the album, to decide which rows
/// show and which are greyed out.
class AlbumModalData {
  const AlbumModalData({
    required this.album,
    required this.links,
    this.showAlbum = true,
    this.gone = false,
    this.pageArtistKey,
  });

  final AlbumTileData album;

  /// Null while the links load, or when the album is gone: the artist and
  /// folder rows are then greyed out.
  final AlbumLinks? links;

  /// False on the page of the album itself.
  final bool showAlbum;

  /// The links were read and found no album (a rescan removed it): the rows
  /// that play or copy it are greyed out. False while the links load.
  final bool gone;

  /// The artist whose page lists the album. Kept for callers; no longer used
  /// to filter the Go to artist list.
  final String? pageArtistKey;

  /// The artists Go to artist offers. Null while the links load.
  List<({String key, String name})>? get linkedArtists => links?.artists;

  /// Whether [links] resolved to no album; loading and errors are not gone.
  static bool goneOf(AsyncValue<AlbumLinks?> links) =>
      links is AsyncData<AlbumLinks?> && links.value == null;
}

/// What the actions do. Each one runs after the modal has closed, except
/// [openArtists], [openFolders] and [openAdvanced], which push a page.
class AlbumModalHandlers {
  const AlbumModalHandlers({
    required this.goToAlbum,
    required this.goToArtist,
    required this.goToFolder,
    required this.showInFileManager,
    required this.playAll,
    required this.shuffle,
    required this.addToPlaylist,
    required this.addAllToFavorites,
    this.openArtists,
    this.openFolders,
    this.openAdvanced,
  });

  final VoidCallback goToAlbum;
  final ValueChanged<String> goToArtist;
  final ValueChanged<String> goToFolder;

  /// Shows the file at the given path in the file manager.
  final ValueChanged<String> showInFileManager;
  final VoidCallback playAll;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;

  /// Puts every local song of the album in Favorites, saying how many went in.
  final VoidCallback addAllToFavorites;
  final void Function(ContextModalNav nav)? openArtists;
  final void Function(ContextModalNav nav)? openFolders;
  final void Function(ContextModalNav nav)? openAdvanced;
}
