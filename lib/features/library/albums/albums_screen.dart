import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_browse_body.dart';
import '../library_route_keys.dart';
import '../widgets/library_sort_button.dart';
import '../widgets/page_material.dart';
import 'album_grid_tile.dart';
import 'album_list_tile.dart';
import 'album_tile_data.dart';
import 'albums_provider.dart';

final _log = Logger('library');

/// Row used to measure the list view.
const _prototypeAlbum = AlbumSummary(
  key: AlbumKey('', ''),
  title: 'Title',
  artist: 'Artist',
  trackCount: 1,
  addedAt: 0,
);

/// Every album as a grid or a list, in the saved sort. Tapping one opens its
/// page.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(albumsProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading the albums failed', next.error, next.stackTrace);
      }
    });
    final sort = ref.watch(settingsProvider.select((s) => s.albumSort));
    final view = ref.watch(settingsProvider.select((s) => s.albumsView));
    final settings = ref.read(settingsProvider.notifier);
    void open(AlbumKey key) => context.go(albumLocation(key));

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navAlbums,
        body: LibraryBrowseBody<AlbumSummary>(
          state: ref.watch(albumsProvider),
          items: ref.watch(sortedAlbumsProvider),
          icon: Icons.album_outlined,
          noRootsMessage: l10n.albumsNoRootsMessage,
          emptyTitle: l10n.albumsEmptyTitle,
          emptyMessage: l10n.albumsEmptyMessage,
          toolbar: Row(
            children: [
              LibrarySortButton<AlbumSortField>(
                choice: sort,
                fields: AlbumSortField.values,
                label: albumSortLabel,
                onChanged: settings.setAlbumSort,
              ),
              const Spacer(),
              SegmentedButton<AlbumsView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AlbumsView.grid,
                    icon: const Icon(Icons.grid_view),
                    tooltip: l10n.albumsGridView,
                  ),
                  ButtonSegment(
                    value: AlbumsView.list,
                    icon: const Icon(Icons.view_list),
                    tooltip: l10n.albumsListView,
                  ),
                ],
                selected: {view},
                onSelectionChanged: (selected) =>
                    settings.setAlbumsView(selected.single),
              ),
            ],
          ),
          builder: (albums) => switch (view) {
            AlbumsView.grid => AlbumGrid(
              albums: [for (final a in albums) AlbumTileData.fromSummary(a)],
              onTap: (album) => open(album.key),
            ),
            AlbumsView.list => ListView.builder(
              prototypeItem: AlbumListTile(
                album: _prototypeAlbum,
                onTap: () {},
              ),
              itemCount: albums.length,
              itemBuilder: (context, i) => AlbumListTile(
                album: albums[i],
                onTap: () => open(albums[i].key),
              ),
            ),
          },
        ),
      ),
    );
  }
}
