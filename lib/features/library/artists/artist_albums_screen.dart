import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/library_route_keys.dart';
import '../albums/album_collection_screen.dart';
import '../library_detail_body.dart';
import 'artist_not_found.dart';
import 'artist_page_data.dart';
import 'artist_page_sections.dart';

/// The two album lists of an artist page.
enum ArtistAlbumSection { albums, appearsOn }

/// The full list of one section of an artist page, read from the same
/// provider entry as the page below it. [routeKey] comes from the URL; a
/// broken key or an artist without tracks shows "not found".
class ArtistAlbumsScreen extends ConsumerWidget {
  const ArtistAlbumsScreen({
    super.key,
    required this.routeKey,
    required this.section,
  });

  final String routeKey;
  final ArtistAlbumSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final artistKey = decodeArtistRouteKey(routeKey);
    final own = section == ArtistAlbumSection.albums;
    return LibraryDetailBody<ArtistPageSections>(
      page: artistKey == null ? null : artistPageProvider(artistKey),
      what: 'the artist',
      // The artist page below logs the same failure.
      logErrors: false,
      notFound: const ArtistNotFound(),
      builder: (sections) => AlbumCollectionScreen(
        key: ValueKey(routeKey),
        title: own ? l10n.artistsAlbums : l10n.artistsAppearsOn,
        ownerName: sections.name,
        albums: own ? sections.albums : sections.appearsOn,
        initialSort: artistAlbumsSort,
        // The albums of "Appears on" hold songs of other artists too.
        showTotals: own,
        albumLocation: (album) => albumUnderLocation(
          own
              ? artistAlbumsLocation(artistKey!)
              : artistAppearsOnLocation(artistKey!),
          album,
        ),
      ),
    );
  }
}
