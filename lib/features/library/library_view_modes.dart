import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/library_sort.dart';

/// How the library screens that offer a grid or a list lay out their items.
/// Kept for the running app only: a restart goes back to the defaults.
class LibraryViewModesState {
  const LibraryViewModesState({this.artists = AlbumsView.list});

  final AlbumsView artists;

  LibraryViewModesState copyWith({AlbumsView? artists}) =>
      LibraryViewModesState(artists: artists ?? this.artists);
}

class LibraryViewModes extends Notifier<LibraryViewModesState> {
  @override
  LibraryViewModesState build() => const LibraryViewModesState();

  void setArtistsView(AlbumsView view) => state = state.copyWith(artists: view);
}

final libraryViewModesProvider =
    NotifierProvider<LibraryViewModes, LibraryViewModesState>(
      LibraryViewModes.new,
    );
