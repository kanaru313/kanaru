import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/artist_summaries.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/artist_tile.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';
import '../library_view_modes.dart';
import '../widgets/library_sort_controls.dart';
import '../widgets/page_material.dart';
import 'artist_grid_tile.dart';
import 'artists_provider.dart';
import 'enqueue_artist.dart';

final _log = Logger('library');

/// Row used to measure the list.
const _prototypeArtist = ArtistSummary(
  key: '',
  name: 'Artist',
  songCount: 1,
  albumCount: 1,
  durationMs: 60000,
);

/// Every artist named in the tracks (guests included), in the saved sort.
/// Tapping one opens their page.
class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(artistsProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading the artists failed', next.error, next.stackTrace);
      }
    });
    final sort = ref.watch(settingsProvider.select((s) => s.artistSort));
    final view = ref.watch(libraryViewModesProvider.select((m) => m.artists));
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    void open(ArtistSummary artist) => context.go(artistLocation(artist.key));
    void enqueue(ArtistSummary artist, QueueAction action) =>
        enqueueArtist(ref, context, action, artist.key, artist.name);

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navArtists,
        actions: [
          if (showActions) ...[
            // Shows the current view; a tap switches to the other one.
            IconButton(
              tooltip: switch (view) {
                AlbumsView.grid => l10n.albumsGridView,
                AlbumsView.list => l10n.albumsListView,
              },
              icon: Icon(switch (view) {
                AlbumsView.grid => AppIcons.viewGrid,
                AlbumsView.list => AppIcons.viewList,
              }),
              onPressed: () => ref
                  .read(libraryViewModesProvider.notifier)
                  .setArtistsView(switch (view) {
                    AlbumsView.grid => AlbumsView.list,
                    AlbumsView.list => AlbumsView.grid,
                  }),
            ),
            const SizedBox(width: 8),
            LibrarySortControls<ArtistSortField>(
              choice: sort,
              fields: ArtistSortField.values,
              label: artistSortLabel,
              onChanged: ref.read(settingsProvider.notifier).setArtistSort,
            ),
          ],
        ],
        body: LibraryBrowseBody<ArtistSummary>(
          hasError: ref.watch(artistsProvider.select((s) => s.hasError)),
          items: ref.watch(sortedArtistsProvider),
          icon: AppIcons.artistOutline,
          noRootsMessage: l10n.artistsNoRootsMessage,
          emptyTitle: l10n.artistsEmptyTitle,
          emptyMessage: l10n.artistsEmptyMessage,
          builder: (artists) => switch (view) {
            AlbumsView.grid => ArtistGrid(
              artists: artists,
              onTap: open,
              onQueueAction: enqueue,
            ),
            AlbumsView.list => ListView.builder(
              padding: libraryListBottomPadding,
              prototypeItem: ArtistTile(artist: _prototypeArtist, onTap: () {}),
              itemCount: artists.length,
              itemBuilder: (context, i) => ArtistTile(
                artist: artists[i],
                onTap: () => open(artists[i]),
                onPlay: () => unawaited(playArtist(ref, artists[i].key)),
                onQueueAction: (action) => enqueue(artists[i], action),
              ),
            ),
          },
        ),
      ),
    );
  }
}
