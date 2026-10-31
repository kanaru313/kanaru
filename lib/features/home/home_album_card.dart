import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show AlbumSummary;
import '../../shared/enqueue_tracks.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/widgets/library_grid/album_grid_tile.dart';
import '../../shared/widgets/library_grid/album_tile_data.dart';

/// One album on a shelf: the Albums grid card. Tapping opens the album page;
/// the menu is the queue menu.
class HomeAlbumCard extends ConsumerWidget {
  const HomeAlbumCard({super.key, required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlbumGridTile(
      data: AlbumTileData.fromSummary(album),
      onTap: () => context.go(albumLocation(album.key)),
      onQueueAction: (action) =>
          enqueueAlbum(ref, context, action, album.key, album.title),
    );
  }
}
