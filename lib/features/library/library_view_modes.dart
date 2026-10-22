import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/library_sort.dart';

/// How the library screens that offer a grid or a list lay out their items.
/// Kept for the running app only: a restart goes back to the defaults.
class LibraryViewModesState {
  const LibraryViewModesState({
    this.artists = AlbumsView.list,
    this.genres = AlbumsView.list,
  });

  final AlbumsView artists;
  final AlbumsView genres;

  LibraryViewModesState copyWith({AlbumsView? artists, AlbumsView? genres}) =>
      LibraryViewModesState(
        artists: artists ?? this.artists,
        genres: genres ?? this.genres,
      );
}

class LibraryViewModes extends Notifier<LibraryViewModesState> {
  @override
  LibraryViewModesState build() => const LibraryViewModesState();

  void setArtistsView(AlbumsView view) => state = state.copyWith(artists: view);

  void setGenresView(AlbumsView view) => state = state.copyWith(genres: view);
}

final libraryViewModesProvider =
    NotifierProvider<LibraryViewModes, LibraryViewModesState>(
      LibraryViewModes.new,
    );
