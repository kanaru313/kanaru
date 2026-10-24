import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/library_view_modes.dart';

/// Starts every library page as a list, for tests that check list rows
/// (library pages other than Songs open as a grid by default).
class _ListViewModes extends LibraryViewModes {
  @override
  LibraryViewModesState build() => const LibraryViewModesState(
    songs: AlbumsView.list,
    artists: AlbumsView.list,
    genres: AlbumsView.list,
    folders: AlbumsView.list,
    languages: AlbumsView.list,
  );
}

/// Provider override that makes every library page start as a list.
final Override listViewModesOverride = libraryViewModesProvider.overrideWith(
  _ListViewModes.new,
);
