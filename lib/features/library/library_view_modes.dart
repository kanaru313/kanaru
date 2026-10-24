import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/library_sort.dart';

/// How the library screens that offer a grid or a list lay out their items.
/// Library pages opened from the sidebar default to the grid. Kept for the
/// running app only: a restart goes back to the defaults.
class LibraryViewModesState {
  const LibraryViewModesState({
    this.songs = AlbumsView.grid,
    this.artists = AlbumsView.grid,
    this.genres = AlbumsView.grid,
    this.folders = AlbumsView.grid,
    this.languages = AlbumsView.grid,
    this.foldersHierarchy = true,
  });

  final AlbumsView songs;
  final AlbumsView artists;
  final AlbumsView genres;
  final AlbumsView folders;
  final AlbumsView languages;

  /// Whether Folders shows the tree under each music folder (otherwise one
  /// flat list of every folder holding songs).
  final bool foldersHierarchy;

  LibraryViewModesState copyWith({
    AlbumsView? songs,
    AlbumsView? artists,
    AlbumsView? genres,
    AlbumsView? folders,
    AlbumsView? languages,
    bool? foldersHierarchy,
  }) => LibraryViewModesState(
    songs: songs ?? this.songs,
    artists: artists ?? this.artists,
    genres: genres ?? this.genres,
    folders: folders ?? this.folders,
    languages: languages ?? this.languages,
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

  void setLanguagesView(AlbumsView view) =>
      state = state.copyWith(languages: view);

  void setFoldersHierarchy(bool hierarchy) =>
      state = state.copyWith(foldersHierarchy: hierarchy);
}

final libraryViewModesProvider =
    NotifierProvider<LibraryViewModes, LibraryViewModesState>(
      LibraryViewModes.new,
    );
