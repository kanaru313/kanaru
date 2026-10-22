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
}
