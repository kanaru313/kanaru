import 'package:flutter/widgets.dart' show ValueChanged, VoidCallback;

import '../../core/database/library_browse_album_links.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import '../widgets/library_grid/album_tile_data.dart';

/// An album with this many artists or more opens a page of artists instead of
/// showing chips (fewer show the chips open).
const albumArtistsOpenBelow = 4;

/// What the actions page needs to know about the album, to decide which rows
/// show and which are greyed out.
class AlbumModalData {
  const AlbumModalData({
    required this.album,
    required this.links,
    this.showAlbum = true,
  });

  final AlbumTileData album;

  /// Null while the links load, or when the album is gone: the artist and
  /// folder rows are then greyed out.
  final AlbumLinks? links;

  /// False on the page of the album itself.
  final bool showAlbum;
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

/// Closes the modal, then calls [then]: every action that leaves the modal
/// goes through here.
void Function(ContextModalNav) albumModalCloseThen(VoidCallback then) => (nav) {
  nav.close();
  then();
};

/// The last part of the directory [path] ("/music/Rock" gives "Rock").
String folderName(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/') return '/';
  return trimmed.substring(trimmed.lastIndexOf('/') + 1);
}

/// The directory that holds [path] ("/music/Rock" gives "/music"); empty for
/// a top-level directory.
String parentPath(String path) {
  final cut = path.lastIndexOf('/');
  return cut <= 0 ? '' : path.substring(0, cut);
}
