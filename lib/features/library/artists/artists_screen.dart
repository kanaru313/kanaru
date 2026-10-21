import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/artist_summaries.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/artist_tile.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_browse_body.dart';
import '../widgets/library_rescan_button.dart';
import '../widgets/library_sort_controls.dart';
import '../widgets/page_material.dart';
import 'artists_provider.dart';
import 'enqueue_artist.dart';

final _log = Logger('library');

/// Row used to measure the list.
const _prototypeArtist = ArtistSummary(
  key: '',
  name: 'Artist',
  songCount: 1,
  albumCount: 1,
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
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navArtists,
        actions: [
          if (showActions)
            LibrarySortControls<ArtistSortField>(
              choice: sort,
              fields: ArtistSortField.values,
              label: artistSortLabel,
              onChanged: ref.read(settingsProvider.notifier).setArtistSort,
            ),
        ],
        body: LibraryRescanStack(
          child: LibraryBrowseBody<ArtistSummary>(
            hasError: ref.watch(artistsProvider.select((s) => s.hasError)),
            items: ref.watch(sortedArtistsProvider),
            icon: Icons.person_outline,
            noRootsMessage: l10n.artistsNoRootsMessage,
            emptyTitle: l10n.artistsEmptyTitle,
            emptyMessage: l10n.artistsEmptyMessage,
            builder: (artists) => ListView.builder(
              padding: const EdgeInsets.only(bottom: libraryRescanClearance),
              prototypeItem: ArtistTile(artist: _prototypeArtist, onTap: () {}),
              itemCount: artists.length,
              itemBuilder: (context, i) => ArtistTile(
                artist: artists[i],
                onTap: () => context.go(artistLocation(artists[i].key)),
                onQueueAction: (action) => enqueueArtist(
                  ref,
                  context,
                  action,
                  artists[i].key,
                  artists[i].name,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
