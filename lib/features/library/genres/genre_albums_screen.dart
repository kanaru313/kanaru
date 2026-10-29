import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/library_route_keys.dart';
import '../albums/album_collection_screen.dart';
import '../library_detail_body.dart';
import 'genre_display_name.dart';
import 'genre_not_found.dart';
import 'genre_page_data.dart';

/// The full list of the albums of a genre, read from the same provider entry
/// as the genre page below it. [routeKey] comes from the URL; a broken key or
/// a genre without tracks shows "not found".
class GenreAlbumsScreen extends ConsumerWidget {
  const GenreAlbumsScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final genreKey = decodeGenreRouteKey(routeKey);
    return LibraryDetailBody<GenrePageData>(
      page: genreKey == null ? null : genrePageProvider(genreKey),
      what: 'the genre',
      // The genre page below logs the same failure.
      logErrors: false,
      notFound: const GenreNotFound(),
      builder: (data) => AlbumCollectionScreen(
        key: ValueKey(routeKey),
        title: l10n.genresAlbums,
        ownerName: genreDisplayName(l10n, genreKey!, data.name),
        albums: data.albums,
        initialSort: genreAlbumsSort,
        // The albums hold songs of other genres too.
        showTotals: false,
        albumLocation: (album) =>
            albumUnderLocation(genreAlbumsLocation(genreKey), album),
      ),
    );
  }
}
