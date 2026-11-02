import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/widgets/library_grid/album_grid_tile.dart';
import '../../../shared/widgets/library_grid/album_tile_data.dart';
import '../../../shared/widgets/library_grid/library_grid_delegate.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';

/// Side padding of album grids.
const albumGridPadding = 24.0;

/// [libraryGridDelegate] for album tiles: artwork and two lines of text.
SliverGridDelegate albumGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: AlbumGridTile.heightFor);

/// [albums] as a scrolling grid, leaving room for the rescan button below.
/// Tile data is made per visible tile, not for the whole list.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({
    super.key,
    required this.albums,
    required this.onTap,
    this.onQueueAction,
  });

  final List<AlbumSummary> albums;
  final void Function(AlbumSummary album) onTap;

  /// An action picked from the menu of [album]; no menus without it.
  final void Function(AlbumSummary album, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          albumGridPadding,
          0,
          albumGridPadding,
          libraryBottomInset,
        ),
        gridDelegate: albumGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
        ),
        itemCount: albums.length,
        itemBuilder: (context, i) => AlbumGridTile(
          data: AlbumTileData.fromSummary(albums[i]),
          onTap: () => onTap(albums[i]),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction!(albums[i], action),
        ),
      ),
    );
  }
}

/// [albums] as a grid inside a [CustomScrollView].
class SliverAlbumGrid extends StatelessWidget {
  const SliverAlbumGrid({
    super.key,
    required this.albums,
    required this.onTap,
    this.onQueueAction,
  });

  final List<AlbumTileData> albums;
  final void Function(AlbumTileData album) onTap;

  /// An action picked from the menu of [album]; no menus without it.
  final void Function(AlbumTileData album, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: albumGridPadding),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid.builder(
          gridDelegate: albumGridDelegate(context, constraints.crossAxisExtent),
          itemCount: albums.length,
          itemBuilder: (context, i) => AlbumGridTile(
            data: albums[i],
            onTap: () => onTap(albums[i]),
            onQueueAction: onQueueAction == null
                ? null
                : (action) => onQueueAction!(albums[i], action),
          ),
        ),
      ),
    );
  }
}
