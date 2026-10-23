import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/library_sort.dart';

/// How the library screens that offer a grid or a list lay out their items.
/// Kept for the running app only: a restart goes back to the defaults.
class LibraryViewModesState {
  const LibraryViewModesState({
    this.songs = AlbumsView.list,
    this.artists = AlbumsView.list,
    this.genres = AlbumsView.list,
    this.folders = AlbumsView.list,
    this.foldersHierarchy = true,
  });

  final AlbumsView songs;
  final AlbumsView artists;
  final AlbumsView genres;
  final AlbumsView folders;

  /// Whether Folders shows the tree under each music folder (otherwise one
  /// flat list of every folder holding songs).
  final bool foldersHierarchy;

  LibraryViewModesState copyWith({
    AlbumsView? songs,
    AlbumsView? artists,
    AlbumsView? genres,
    AlbumsView? folders,
    bool? foldersHierarchy,
  }) => LibraryViewModesState(
    songs: songs ?? this.songs,
    artists: artists ?? this.artists,
    genres: genres ?? this.genres,
    folders: folders ?? this.folders,
    foldersHierarchy: foldersHierarchy ?? this.foldersHierarchy,
  );
}

class LibraryViewModes extends Notifier<LibraryViewModesState> {
  @override
  LibraryViewModesState build() => const LibraryViewModesState();

  void setSongsView(AlbumsView view) => state = state.copyWith(songs: view);

  void setArtistsView(AlbumsView view) => state = state.copyWith(artists: view);

  void setGenresView(AlbumsView view) => state = state.copyWith(genres: view);

  void setFoldersView(AlbumsView view) => state = state.copyWith(folders: view);

  void setFoldersHierarchy(bool hierarchy) =>
      state = state.copyWith(foldersHierarchy: hierarchy);
}

final libraryViewModesProvider =
    NotifierProvider<LibraryViewModes, LibraryViewModesState>(
      LibraryViewModes.new,
    );
