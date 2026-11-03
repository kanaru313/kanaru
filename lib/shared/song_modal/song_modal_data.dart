import 'package:flutter/widgets.dart' show ValueChanged, VoidCallback;

import '../../core/database/library_browse_track_links.dart';
import '../../core/database/song_row.dart';
import '../widgets/context_modal/context_modal_nav.dart';

/// What the actions page needs to know about the song and the world around
/// it, to decide which rows show and which are greyed out.
class SongModalData {
  const SongModalData({
    required this.song,
    required this.links,
    required this.isFavorite,
    required this.hasLibrary,
    required this.canFindLyrics,
    this.showAlbum = true,
    this.pageArtistKey,
    this.showFolder = true,
  });

  final SongRow song;

  /// Null while the links load, or when the track is gone: the artist and
  /// album rows are then greyed out.
  final TrackLinks? links;

  /// Null until the favorite state is read.
  final bool? isFavorite;

  /// False leaves out the favorite and lyrics actions.
  final bool hasLibrary;
  final bool canFindLyrics;

  /// False on the page of the song's own album.
  final bool showAlbum;

  /// The artist of the page the row is on: Go to artist and Go to album
  /// artist list the others only. Null elsewhere.
  final String? pageArtistKey;

  /// False on the song's folder page: no Go to folder, a Show in file
  /// manager row instead.
  final bool showFolder;

  /// False for a song that is not a file on this machine (a future remote
  /// source): it has no folder to go to.
  bool get hasLocalPath => song.path.isNotEmpty && !song.path.contains('://');
}

/// What the actions do. Each one runs after the modal has closed, except
/// [openAdvanced], which pushes a page of the modal.
class SongModalHandlers {
  const SongModalHandlers({
    required this.goToAlbum,
    required this.goToArtist,
    required this.goToFolder,
    required this.showInFileManager,
    required this.addToPlaylist,
    required this.setFavorite,
    required this.findLyrics,
    this.openAdvanced,
  });

  final VoidCallback goToAlbum;
  final ValueChanged<String> goToArtist;
  final VoidCallback goToFolder;
  final VoidCallback showInFileManager;
  final VoidCallback addToPlaylist;
  final ValueChanged<bool> setFavorite;
  final VoidCallback findLyrics;
  final void Function(ContextModalNav nav)? openAdvanced;
}
