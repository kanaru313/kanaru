import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_browse_body.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/enqueue_tracks.dart';
import '../widgets/library_sort_controls.dart';
import '../widgets/page_material.dart';
import 'album_grid_tile.dart';
import 'album_list_view.dart';
import 'albums_view_toggle.dart';
import 'albums_provider.dart';

final _log = Logger('library');

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
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    void open(AlbumKey key) => context.go(albumLocation(key));

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navAlbums,
        actions: [
          if (showActions) ...[
            const AlbumsViewToggle(),
            const SizedBox(width: 8),
            LibrarySortControls<AlbumSortField>(
              choice: sort,
              fields: AlbumSortField.values,
              label: albumSortLabel,
              onChanged: settings.setAlbumSort,
            ),
          ],
        ],
        body: LibraryBrowseBody<AlbumSummary>(
          hasError: ref.watch(albumsProvider.select((s) => s.hasError)),
          items: ref.watch(sortedAlbumsProvider),
          icon: AppIcons.albumOutlined,
          noRootsMessage: l10n.albumsNoRootsMessage,
          emptyTitle: l10n.albumsEmptyTitle,
          emptyMessage: l10n.albumsEmptyMessage,
          builder: (albums) => switch (view) {
            AlbumsView.grid => AlbumGrid(
              albums: albums,
              onTap: (album) => open(album.key),
              onQueueAction: (album, action) =>
                  enqueueAlbum(ref, context, action, album.key, album.title),
            ),
            AlbumsView.list => AlbumListView(
              albums: albums,
              onTap: (album) => open(album.key),
              onQueueAction: (album, action) =>
                  enqueueAlbum(ref, context, action, album.key, album.title),
            ),
          },
        ),
      ),
    );
  }
}
