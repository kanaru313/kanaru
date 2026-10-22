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

  test('artists default to the list and can be switched', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(libraryViewModesProvider).artists, AlbumsView.list);
    container
        .read(libraryViewModesProvider.notifier)
        .setArtistsView(AlbumsView.grid);

    expect(container.read(libraryViewModesProvider).artists, AlbumsView.grid);
  });

  test('a new container starts from the defaults again', () {
    final first = ProviderContainer();
    first
        .read(libraryViewModesProvider.notifier)
        .setArtistsView(AlbumsView.grid);
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);

    expect(second.read(libraryViewModesProvider).artists, AlbumsView.list);
  });

  test('genres default to the list and can be switched apart from artists', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(libraryViewModesProvider).genres, AlbumsView.list);
    container
        .read(libraryViewModesProvider.notifier)
        .setGenresView(AlbumsView.grid);

    final modes = container.read(libraryViewModesProvider);
    expect(modes.genres, AlbumsView.grid);
    expect(modes.artists, AlbumsView.list);
  });

  test('folders default to the list with the tree on, each set apart', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final modes = container.read(libraryViewModesProvider);
    expect(modes.folders, AlbumsView.list);
    expect(modes.foldersHierarchy, isTrue);

    container
        .read(libraryViewModesProvider.notifier)
        .setFoldersView(AlbumsView.grid);
    container
        .read(libraryViewModesProvider.notifier)
        .setFoldersHierarchy(false);

    final changed = container.read(libraryViewModesProvider);
    expect(changed.folders, AlbumsView.grid);
    expect(changed.foldersHierarchy, isFalse);
    expect(changed.artists, AlbumsView.list);
    expect(changed.genres, AlbumsView.list);
  });
}
