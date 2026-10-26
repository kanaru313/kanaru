import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/library_view_modes.dart';

void main() {
  test('the view outlives its listeners', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(libraryViewModesProvider, (_, _) {});
    container
        .read(libraryViewModesProvider.notifier)
        .setArtistsView(AlbumsView.grid);
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(libraryViewModesProvider).artists, AlbumsView.grid);
  });

  test('songs default to the list, every other library page to the grid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final modes = container.read(libraryViewModesProvider);
    expect(modes.songs, AlbumsView.list);
    expect(modes.artists, AlbumsView.grid);
    expect(modes.genres, AlbumsView.grid);
    expect(modes.folders, AlbumsView.grid);
    expect(modes.languages, AlbumsView.grid);
    expect(modes.foldersHierarchy, isTrue);
  });

  test('artists can be switched to the list', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryViewModesProvider.notifier)
        .setArtistsView(AlbumsView.list);

    expect(container.read(libraryViewModesProvider).artists, AlbumsView.list);
  });

  test('languages can be switched apart from the other pages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryViewModesProvider.notifier)
        .setLanguagesView(AlbumsView.list);

    final modes = container.read(libraryViewModesProvider);
    expect(modes.languages, AlbumsView.list);
    expect(modes.songs, AlbumsView.list);
    expect(modes.artists, AlbumsView.grid);
  });

  test('a new container starts from the defaults again', () {
    final first = ProviderContainer();
    first
        .read(libraryViewModesProvider.notifier)
        .setArtistsView(AlbumsView.list);
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);

    expect(second.read(libraryViewModesProvider).artists, AlbumsView.grid);
  });

  test('genres can be switched apart from artists', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryViewModesProvider.notifier)
        .setGenresView(AlbumsView.list);

    final modes = container.read(libraryViewModesProvider);
    expect(modes.genres, AlbumsView.list);
    expect(modes.artists, AlbumsView.grid);
  });

  test('folders view and the tree are set apart', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryViewModesProvider.notifier)
        .setFoldersView(AlbumsView.list);
    container
        .read(libraryViewModesProvider.notifier)
        .setFoldersHierarchy(false);

    final changed = container.read(libraryViewModesProvider);
    expect(changed.folders, AlbumsView.list);
    expect(changed.foldersHierarchy, isFalse);
    expect(changed.artists, AlbumsView.grid);
    expect(changed.genres, AlbumsView.grid);
  });
}
