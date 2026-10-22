import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';
import '../library_view_modes.dart';
import '../widgets/page_material.dart';
import 'enqueue_genre.dart';
import 'genre_grid_tile.dart';
import 'genre_tile.dart';
import 'genres_provider.dart';

final _log = Logger('library');

/// Row used to measure the list.
const _prototypeGenre = GenreSummary(
  key: '',
  name: 'Genre',
  songCount: 1,
  raws: [],
);

/// Every genre named in the tracks, by name, as a list or a grid of round
/// tiles. Tapping one opens its page.
class GenresScreen extends ConsumerWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(genresProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading the genres failed', next.error, next.stackTrace);
      }
    });
    final view = ref.watch(libraryViewModesProvider.select((m) => m.genres));
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    void open(GenreSummary genre) => context.go(genreLocation(genre.key));
    void enqueue(GenreSummary genre, QueueAction action) =>
        enqueueGenre(ref, context, action, genre);

    return PageMaterial(
      child: PageScaffold(
        title: l10n.genresTitle,
        actions: [
          if (showActions)
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
                  .setGenresView(switch (view) {
                    AlbumsView.grid => AlbumsView.list,
                    AlbumsView.list => AlbumsView.grid,
                  }),
            ),
        ],
        body: LibraryBrowseBody<GenreSummary>(
          hasError: ref.watch(genresProvider.select((s) => s.hasError)),
          items: ref.watch(genresProvider).value,
          icon: AppIcons.genreOutlined,
          noRootsMessage: l10n.genresNoRootsMessage,
          emptyTitle: l10n.genresEmptyTitle,
          emptyMessage: l10n.genresEmptyMessage,
          builder: (genres) => switch (view) {
            AlbumsView.grid => GenreGrid(
              genres: genres,
              onTap: open,
              onQueueAction: enqueue,
            ),
            AlbumsView.list => ListView.builder(
              padding: libraryListBottomPadding,
              prototypeItem: GenreTile(genre: _prototypeGenre, onTap: () {}),
              itemCount: genres.length,
              itemBuilder: (context, i) => GenreTile(
                genre: genres[i],
                onTap: () => open(genres[i]),
                onQueueAction: (action) => enqueue(genres[i], action),
              ),
            ),
          },
        ),
      ),
    );
  }
}
