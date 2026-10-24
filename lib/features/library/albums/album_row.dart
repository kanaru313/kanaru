import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/card_shelf.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'album_grid_tile.dart';
import 'album_tile_data.dart';

/// Width of the artwork of a tile in an [SliverAlbumRow].
const _artworkWidth = 160.0;

/// [albums] as one line of grid tiles inside a [CustomScrollView], scrolling
/// sideways like the Home shelves ([CardShelf]): arrow buttons, mouse drag,
/// trackpad and Shift+wheel.
class SliverAlbumRow extends StatelessWidget {
  const SliverAlbumRow({
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
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: CardShelf(
      itemCount: albums.length,
      itemExtent: _artworkWidth + gridTilePadding * 2,
      height:
          AlbumGridTile.heightFor(context, _artworkWidth) + gridTilePadding * 2,
      // The arrows center on the artwork, not on the text below it.
      arrowTop: gridTilePadding + _artworkWidth / 2 - 24,
      itemBuilder: (context, i) => AlbumGridTile(
        data: albums[i],
        onTap: () => onTap(albums[i]),
        onQueueAction: onQueueAction == null
            ? null
            : (action) => onQueueAction!(albums[i], action),
      ),
    ),
  );
}
