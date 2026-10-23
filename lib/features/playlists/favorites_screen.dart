import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'playlist_page_body.dart';
import 'playlist_page_data.dart';
import 'playlist_screen_states.dart';

final _log = Logger('playlists');

/// The Favorites page: the Favorites playlist (`kind = 'favorites'`) shown
/// with the playlist page body, without rename or delete. Before the first
/// like there is no such playlist and the page says how to fill it.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(libraryDatabaseProvider) == null) {
      return const PlaylistsUnavailable();
    }
    ref.listen(favoritesPlaylistIdProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading the favorites playlist failed',
          next.error,
          next.stackTrace,
        );
      }
    });
    final Widget body = switch (ref.watch(favoritesPlaylistIdProvider)) {
      AsyncData(value: final id?) => _FavoritesPage(id),
      AsyncData() => const _NoFavorites(),
      AsyncError() => const PlaylistsUnavailable(),
      _ => const LibraryLoading(),
    };
    // A page in a branch needs its own Material for the ink of rows.
    return Material(type: MaterialType.transparency, child: body);
  }
}

class _FavoritesPage extends ConsumerWidget {
  const _FavoritesPage(this.id);

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(playlistPageHeadProvider(id), (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading favorites failed', next.error, next.stackTrace);
      }
    });
    return ref
        .watch(playlistPageHeadProvider(id))
        .when(
          skipLoadingOnReload: true,
          skipError: true,
          loading: () => const LibraryLoading(),
          error: (error, stack) => const PlaylistsUnavailable(),
          // Gone (deleted outside the app): the id stream catches up.
          data: (load) => switch (load.head) {
            final head? => PlaylistPageBody(head, headSeq: load.seq),
            null => const _NoFavorites(),
          },
        );
  }
}

class _NoFavorites extends StatelessWidget {
  const _NoFavorites();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navFavorites,
      body: EmptyState(
        icon: AppIcons.favoriteOutline,
        title: l10n.navFavorites,
        message: l10n.favoritesEmptyMessage,
      ),
    );
  }
}
